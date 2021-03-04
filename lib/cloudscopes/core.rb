require 'aws-sdk-cloudwatch'
require 'logger'
require 'yaml'

require 'cloudscopes/metric'

module Cloudscopes

  class << self
    def init(config_file:, publish: true)
      return if @initialized

      begin
        hypervisor_uuid = File.read("/sys/hypervisor/uuid")
        unless hypervisor_uuid.start_with?("ec2")
          raise "Unexpected hypervisor UUID: #{hypervisor_uuid}. Not running in EC2, so won't publish!"
        end
      rescue => e
        raise unless ENV["CLOUDSCOPES_RUNS_ON_EC2"]
        log_error("Failed EC2 check with hypervisor UUID.", e)
      end

      configuration = YAML.load(File.read(config_file))
      @publish = publish
      @settings = configuration['settings']
      if region = ENV['CLOUDSCOPES_REGION']
        @settings['region'] = region
      end
      default_sample_interval = @settings['default_sample_interval'].to_i || 60
      if default_sample_interval < 10 || default_sample_interval > 86_400
        raise "The sample interval must be a value from 10 to 86,400 seconds."
      end
      metric_definitions = configuration['metrics'] || {}
      if metric_dir = @settings['metric_definition_dir']
        merge_metric_definitions(metric_definitions,
            Dir.glob("#{metric_dir}/*").select(&File.method(:file?)))
      end
      @metric_groups = metric_groups_from_definitions(metric_definitions,
          default_sample_interval: default_sample_interval)
      if plugin_dir = @settings['plugin_dir']
        @metric_groups += metric_groups_from_plugin_files(
            Dir.glob("#{plugin_dir}/*.rb").select(&File.method(:file?)),
            default_sample_interval: default_sample_interval)
      end
      @data_dimensions ||=
          eval_dimension_specs(@settings['dimensions'] || {'InstanceId' => '#{ec2.instance_id}'})
      @initialized = true
    end

    def samples
      now = Time.now
      metric_groups
          .select {|group| group.next_sampling_at < now }
          .each {|group| group.compute_next_sampling_at_from(now) }
          .collect(&:samples)
    end

    def next_sampling_time
      metric_groups.map(&:next_sampling_at).sort.first
    end

    def publish(samples)
      samples.each do |type, metric_samples|
        begin
          valid_data = metric_samples.select(&:valid?)
          next if valid_data.empty?
          # slice metrics to chunks
          # put_metric_data is limited to 40KB per POST request
          valid_data.each_slice(4) do |slice|
            client.put_metric_data(
              namespace: type,
              metric_data: slice.collect(&:to_cloudwatch_metric_data),
            )
          end
        rescue => e
          log_error("Error publishing metrics for #{type}.", e)
        end
      end
    end

    def log
      @logger ||= Logger.new(STDOUT)
    end

    def log_error(msg, exception)
      log.error(msg)
      log.error(exception)
    end

    def reset
      Instance.clear_cache
      metric_groups.each(&:reset)
    end

    %w(
      data_dimensions
      metric_groups
      publish?
      settings
    ).each do |name|
      instance_var = "@#{name.gsub(/\?$/, "")}"
      define_method(name) do
        raise "Cloudscopes not initialized" unless @initialized
        instance_variable_get(instance_var)
      end
    end

    private

    def client
      @client ||= Aws::CloudWatch::Client.new(
        access_key_id: @settings['aws-key'],
        secret_access_key: @settings['aws-secret'],
        region: @settings['region'],
      )
    end

    def eval_dimension_specs(specs)
      specs.collect do |key, value|
        begin
          if !value.start_with?('"') and value.include?('#')
            # user wants to expand a string expression, but can't be bothered with escaping double
            # quotes
            quoted_value = %("#{value}")
          end
          value = eval(quoted_value || value)
        rescue NameError
          # assume the user meant to send the static text
        end
        {name: key, value: value}
      end
    end

    def merge_metric_definitions(metric_definitions, files)
      files.each do |metric_file|
        YAML.load(File.read(metric_file)).each do |namespace, definitions|
          metric_definitions[namespace] ||= []
          metric_definitions[namespace] += definitions
        end
      end
    end

    def metric_groups_from_definitions(definitions, **options)
      definitions.map do |category, metrics|
        Metric::Group.from_definition(category, metrics, **options)
      end
    end

    def metric_groups_from_plugin_files(plugin_files, **options)
      plugin_files.map do |file|
        code = File.read(file)
        name = File.basename(file)
        unless (ext = File.extname(file)).empty?
          name = name[0...-ext.length]
        end
        begin
          Metric::Group.from_plugin(name, code, **options)
        rescue => e
          log_error("Error loading #{file}.", e)
        end
      end.compact
    end
  end
end
