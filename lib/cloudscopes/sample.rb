module Cloudscopes

  module Sample

    module Base
      def unit
        nil
      end

      def dimensions
        Cloudscopes.data_dimensions
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

    class Code
      include Base

      attr_reader :name, :value, :unit

      def initialize(metric)
        @name = metric['name']
        @unit = metric['unit']
        @value = nil

        begin
          return if metric['requires'] and ! Cloudscopes.get_binding.eval(metric['requires'])
          @value = Cloudscopes.get_binding.eval(metric['value'])
        rescue => e
          STDERR.puts("Error evaluating #{@name}: #{e}")
          puts e.backtrace
        end
      end
    end

    class Simple
      include Base

      attr_reader :name, :value, :unit

      def initialize(name:, value:, unit: nil)
        @name = name
        @value = value
        @unit = unit
      end
    end

    class Collector
      class << self
        def samples(source, code)
          collector = new
          collector.instance_eval(code)
          category = collector.instance_variable_get("@category") or
              raise "Code from #{source} did not specify category."
          [category, collector.instance_variable_get("@__samples")]
        end
      end

      def initialize
        @__samples = []
      end

      def category(category)
        @category = category
      end

      def sample(*args)
        @__samples << Simple.new(*args)
      end

      def method_missing(method, *args)
        Cloudscopes.send(method, *args)
      end
    end
  end

end
