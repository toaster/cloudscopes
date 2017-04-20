require 'yaml'
require 'aws-sdk'

module Cloudscopes

  class << self
    def init(config_file:, publish: true)
      return if @initialized
      configuration = YAML.load(File.read(config_file))
      @settings = configuration['settings']
      @metrics = configuration['metrics'] || {}
      @publish = publish
      if metric_dir = @settings['metric_definition_dir']
        merge_metric_definitions(Dir.glob("#{metric_dir}/*").select(&File.method(:file?)))
      end
      if plugin_dir = @settings['plugin_dir']
        @plugin_files = Dir.glob("#{plugin_dir}/*").select(&File.method(:file?))
      end
      @initialized = true
    end

    def data_dimensions
      @data_dimensions ||=
          eval_dimension_specs(settings['dimensions'] || {'InstanceId' => '#{ec2.instance_id}'})
    end

    def samples
      metrics.collect do |category, metrics|
        [category, Array(metrics).map(&Sample::Code.method(:new))]
      end + code_snippets.collect do |path, code|
        Sample::Collector.samples(path, code)
      end
    end

    def publish(samples)
      unless Kernel.system(
          "test -f /sys/hypervisor/uuid && test `head -c 3 /sys/hypervisor/uuid` = ec2")
        raise "Not running in EC2, so won't publish!"
      end
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
        rescue Exception => e
          puts "Error publishing metrics for #{type}: #{e}"
        end
      end
    end

    %w(
      publish?
      settings
      metrics
      plugin_files
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

    def merge_metric_definitions(files)
      files.each do |metric_file|
        YAML.load(File.read(metric_file)).each do |namespace, definitions|
          @metrics[namespace] ||= []
          @metrics[namespace] += definitions
        end
      end
    end

    def code_snippets
      @code_snippets ||=
          if plugin_files
            plugin_files.zip(plugin_files.map(&File.method(:read)))
          else
            []
          end
    end
  end
end
