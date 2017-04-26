require 'cloudscopes/sample'

module Cloudscopes
  module Metric
    class SampleProvider
      def initialize(name, code)
        klass = Class.new { include Instance }
        Object.const_set(name, klass)
        klass.class_eval(code)
        @metric = klass.new
        @category = klass.category or raise "#{name} has no category specified."
        @compute_samples = klass.instance_variable_get("@compute_samples")
      end

      def samples
        collector = SampleCollector.new(@metric)
        collector.instance_eval(&@compute_samples)
        [@category, collector.instance_variable_get("@samples")]
      end
    end

    class SampleCollector
      def initialize(metric)
        @samples = []
        @metric = metric
      end

      def sample(*args)
        @samples << Sample::Simple.new(*args)
      end

      def method_missing(method, *args)
        @metric.send(method, *args)
      end
    end

    module Instance
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

      def method_missing(method, *args)
        Cloudscopes.send(method, *args)
      end
    end
  end
end
