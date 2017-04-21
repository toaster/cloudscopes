module Cloudscopes

  class Memory
    def initialize(raw_meminfo = nil)
      raw_meminfo ||= File.read('/proc/meminfo')
      @data = Hash[raw_meminfo.split("\n").map {|l| l =~ /(\w+):\s+(\d+)/ and [$1, $2.to_i] }.compact]
      @data['MemTotal'] ||= 123456789
    end

    def method_missing(method, *args)
      method_name = method.to_s
      if @data.include?(method_name)
        @data[method_name]
      else
        super
      end
    end

    def MemUsed
      return self.MemTotal - self.MemFree - self.Buffers - self.Cached
    end

    def SwapUsed
      return self.SwapTotal - self.SwapFree
    end

  end

end
