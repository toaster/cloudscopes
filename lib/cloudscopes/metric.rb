require 'cloudscopes/sample'

module Cloudscopes
  module Metric
    class SampleProvider
      def initialize(name, code)
        klass = Class.new { include Instance }
        klass_name = name.capitalize.gsub(/_([a-z])/) { $1.upcase }
        Object.const_set(klass_name, klass)
        klass.class_eval(code)
        @metric = klass.new
        @metric.instance_variable_set("@name", name)
        @category = klass.category || klass_name
        @compute_samples = klass.instance_variable_get("@compute_samples")
      end

      def samples
        collector = SampleCollector.new(@metric)
        begin
          collector.instance_eval(&@compute_samples)
        rescue => e
          STDERR.puts("Error sampling #{@metric.class.name}: #{e}")
          STDERR.puts(e.backtrace)
        end
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

      def system # must define, otherwise kernel.system matches
        Cloudscopes.system
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

      def log(message)
        File.open("/var/log/cloudscopes/plugins/#{@name}.log", "a") do |f|
          f.puts message
        end
      end

      def method_missing(method, *args)
        Cloudscopes.send(method, *args)
      end
    end
  end
end
