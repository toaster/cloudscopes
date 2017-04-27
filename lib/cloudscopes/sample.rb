module Cloudscopes

  module Sample

    class Base
      attr_reader :name, :value, :unit, :dimensions

      def initialize
        @dimensions = Cloudscopes.data_dimensions
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

    class Code < Base
      def initialize(metric)
        super()

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

    class Simple < Base
      def initialize(name:, value:, unit: nil, dimensions: nil)
        super()
        @name = name
        @value = value
        @unit = unit
        @dimensions = dimensions.map {|name, value| {name: name, value: value} } if dimensions
      end
    end
  end

end
