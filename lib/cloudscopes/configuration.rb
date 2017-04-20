require 'yaml'
require 'aws-sdk'

module Cloudscopes

  class << self
    def init
      @opts = Cloudscopes::Options.new
      configuration = YAML.load(File.read(@opts.config_file))
      @settings = configuration['settings']
      @metrics = configuration['metrics'] || {}
      if metric_dir = @settings['metric_definition_dir']
        merge_metric_definitions(Dir.glob("#{metric_dir}/*").select(&File.method(:file?)))
      end
      @metrics
    end

    def should_publish
      @opts.publish
    end

    def client
      @client ||= Aws::CloudWatch::Client.new(
        access_key_id: @settings['aws-key'],
        secret_access_key: @settings['aws-secret'],
        region: @settings['region'],
      )
    end

    def data_dimensions
      @data_dimensions ||=
          eval_dimension_specs(settings['dimensions'] || {'InstanceId' => '#{ec2.instance_id}'})
    end

    private

    def eval_dimension_specs(specs)
      specs.collect do |key, value|
        begin
          if !value.start_with?('"') and value.include?('#')
            # user wants to expand a string expression, but can't be bothered with escaping double
            # quotes
            quoted_value = %("#{value}")
          end
          value = Cloudscopes.get_binding.eval(quoted_value || value)
        rescue NameError
          # assume the user meant to send the static text
        end
        {name: key, value: value}
      end
    end

    private

    def merge_metric_definitions(files)
      files.each do |metric_file|
        YAML.load(File.read(metric_file)).each do |namespace, definitions|
          @metrics[namespace] ||= []
          @metrics[namespace] += definitions
        end
      end
    end
  end
end
