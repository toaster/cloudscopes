require 'sys/filesystem'

module Cloudscopes

  class Filesystem

    def mountpoints
      @@mountpoints ||= Sys::Filesystem.mounts.reject do |m|
        %w(cgroup tmpfs devtmpfs proc sysfs devpts binfmt_misc).include?(m.mount_type)
      end.map(&:mount_point)
    end

    def df(path)
      Sys::Filesystem.stat(path)
    end

  end

end

