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

  module Const
    class << self
      def name_from_underscore_name(name)
        name.capitalize.gsub(/_([a-z])/) { $1.upcase }
      end

      def for(receiver)
        @const_cache ||= Hash.new do |h, k|
          h[k] = Cloudscopes.const_get(name_from_underscore_name(k))
        end
        @const_cache[receiver]
      end
    end
  end

  def self.method_missing(*args)
    receiver = args.shift.to_s
    if args.empty?
      @instance_cache ||= Hash.new {|h, k| h[k] = Const.for(k).new }
      @instance_cache[receiver]
    else
      Const.for(receiver).new(*args)
    end
  end

end
