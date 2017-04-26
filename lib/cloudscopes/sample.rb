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
          STDERR.puts(e.backtrace)
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
  end

end
