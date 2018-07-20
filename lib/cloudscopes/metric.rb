require 'logger'

module Cloudscopes
  module Metric
    module Group
      module Plugin
        # plugin classes will be placed here
      end

      class << self
        def from_plugin(*args)
          PluggedIn.new(*args)
        end

        def from_definition(*args)
          Defined.new(*args)
        end
      end

      module Base
        def next_sampling_at
          @next_sampling_at || Time.at(0)
        end

        def compute_next_sampling_at_from(last_sampling)
          @next_sampling_at ||= last_sampling
          while @next_sampling_at <= last_sampling
            @next_sampling_at += @sample_interval
          end
        end
      end

      class PluggedIn
        include Cloudscopes::Metric::Group::Base

        def initialize(name, code, default_sample_interval:)
          klass = Class.new { include Base }
          klass_name = Const.name_from_underscore_name(name)
          Plugin.const_set(klass_name, klass)
          klass.class_eval(code)
          @group = klass.new
          @group.instance_variable_set("@name", name)
          @category = klass.category || klass_name
          @compute_samples = klass.instance_variable_get("@compute_samples")
          @sample_interval =
              klass.instance_variable_get("@sample_interval") || default_sample_interval
        end

        def samples
          collector = SampleCollector.new(@group)
          begin
            collector.instance_eval(&@compute_samples)
          rescue => e
            Cloudscopes.log_error("Error sampling #{@group.class.name}.", e)
          end
          [@category, collector.instance_variable_get("@samples")]
        end

        def reset
          @group.reset
        end

        module Base
          class << self
            def included(base)
              base.extend(ClassMethods)
            end
          end

          module ClassMethods
            def category(category = nil)
              category ? @category = category : @category
            end

            def describe_samples(&block)
              @compute_samples = block
            end

            def sample_interval(value)
              @sample_interval = value.to_i
              if @sample_interval < 10 || @sample_interval > 86_400
                raise "The sample interval must be a value from 10 to 86,400 seconds."
              end
            end
          end

          def log
            @log ||= Logger.new(@STDOUT, progname: @name)
          end

          def reset
          end

          def method_missing(method, *args)
            Cloudscopes.send(method, *args)
          end
        end

        class SampleCollector
          def initialize(metric)
            @samples = []
            @metric = metric
          end

          def sample(aggregate: false, **options)
            @samples << Sample.new(**options)
            if aggregate
              aggregation_dimensions = aggregate if Hash === aggregate
              aggregation_dimensions ||= {}
              @samples << Sample.new(**options, dimensions: aggregation_dimensions)
            end
          end

          def system # must define, otherwise kernel.system matches
            Cloudscopes.system
          end

          def method_missing(method, *args)
            @metric.send(method, *args)
          end
        end
      end

      class Defined
        include Cloudscopes::Metric::Group::Base

        def initialize(category, metric_definitions, default_sample_interval:)
          @category = category
          @metrics = metric_definitions.map(&Metric.method(:new))
          @sample_interval = default_sample_interval
        end

        def samples
          [@category, @metrics.map(&:sample)]
        end

        def reset
        end

        class Metric
          def initialize(definition)
            @name = definition['name']
            @unit = definition['unit']
            @dimensions = definition['dimensions']
            @value_callback = eval("Proc.new { #{definition['value']} }")
            if definition['requires']
              @requires_callback = eval("Proc.new { #{definition['requires']} }")
            end
          end

          def sample
            begin
              if !@requires_callback || Cloudscopes.instance_eval(&@requires_callback)
                value = Cloudscopes.instance_eval(&@value_callback)
              end
            rescue => e
              Cloudscopes.log_error("Error evaluating #{@name}.", e)
            end
            Sample.new(name: @name, value: value, unit: @unit, dimensions: @dimensions)
          end
        end
      end
    end

    class Sample
      attr_reader :name, :value, :unit, :dimensions, :storage_resolution

      def initialize(name:, value:, unit: nil, dimensions: nil, storage_resolution: nil)
        super()
        @name = name
        @value = value
        @unit = unit
        @dimensions = dimensions.map {|name, value| {name: name, value: value} } if dimensions
        @dimensions ||= Cloudscopes.data_dimensions
        @storage_resolution = storage_resolution
      end

      def valid?
        !value.nil?
      end

      def to_cloudwatch_metric_data
        return unless valid?
        data = { metric_name: name, value: value }
        data[:unit] = unit if unit
        data[:dimensions] = dimensions
        data[:storage_resolution] = 1 if storage_resolution && storage_resolution < 60
        data
      end
    end
  end
end
