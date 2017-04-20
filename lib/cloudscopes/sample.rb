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

      def initialize(namespace, metric)
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

  end

end
