require 'cloudscopes/configuration'
require 'cloudscopes/globals'
require 'cloudscopes/options'
require 'cloudscopes/sample'
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

  def self.get_binding
    return binding()
  end

  def self.method_missing(*args)
    Cloudscopes.const_get(args.shift.to_s.capitalize).new(*args)
  end

end
