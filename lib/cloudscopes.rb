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

  def self.method_missing(*args)
    Cloudscopes.const_get(args.shift.to_s.capitalize).new(*args)
  end

end
