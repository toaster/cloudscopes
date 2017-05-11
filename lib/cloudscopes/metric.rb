require 'logger'

module Cloudscopes
  module Metric
    module Group
      class << self
        def from_plugin(*args)
          PluggedIn.new(*args)
        end

        def from_definition(*args)
          Defined.new(*args)
        end
      end

      class PluggedIn
        def initialize(name, code)
          klass = Class.new { include Base }
          klass_name = Const.name_from_underscore_name(name)
          Object.const_set(klass_name, klass)
          klass.class_eval(code)
          @group = klass.new
          @group.instance_variable_set("@name", name)
          @category = klass.category || klass_name
          @compute_samples = klass.instance_variable_get("@compute_samples")
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
          end

          def log
            @log ||= Logger.new("/var/log/cloudscopes/plugins/#{@name}.log")
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
            @samples << Sample.new(**options, dimensions: {}) if aggregate
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
        def initialize(category, metric_definitions)
          @category = category
          @metrics = metric_definitions.map(&Metric.method(:new))
        end

        def samples
          [@category, @metrics.map(&:sample)]
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
      attr_reader :name, :value, :unit, :dimensions

      def initialize(name:, value:, unit: nil, dimensions: nil)
        super()
        @name = name
        @value = value
        @unit = unit
        @dimensions = dimensions.map {|name, value| {name: name, value: value} } if dimensions
        @dimensions ||= Cloudscopes.data_dimensions
      end

      def valid?
        !value.nil?
      end

      def to_cloudwatch_metric_data
        return unless valid?
        data = { metric_name: name, value: value }
        data[:unit] = unit if unit
        data[:dimensions] = dimensions
        data
      end
    end
  end
end
