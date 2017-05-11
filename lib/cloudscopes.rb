require 'cloudscopes/core'
require 'cloudscopes/version'

require 'cloudscopes/docker'
require 'cloudscopes/ec2'
require 'cloudscopes/filesystem'
require 'cloudscopes/memory'
require 'cloudscopes/network'
require 'cloudscopes/process'
require 'cloudscopes/redis'
require 'cloudscopes/system'

module Cloudscopes

  class << self
    def method_missing(*args)
      receiver = args.shift.to_s
      if args.empty?
        @instance_cache ||= Hash.new {|h, k| h[k] = _const_for(k).new }
        @instance_cache[receiver]
      else
        _const_for(receiver).new(*args)
      end
    end

    private

    def _const_for(receiver)
      @const_cache ||= Hash.new {|h, k| h[k] = Cloudscopes.const_get(k.capitalize) }
      @const_cache[receiver]
    end
  end
end
