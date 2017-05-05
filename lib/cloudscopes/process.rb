require 'etc'

module Cloudscopes

  class Process

    class SystemProcess

      @@maxpid = File.read('/proc/sys/kernel/pid_max').to_i

      def initialize(id)
        @id = id.to_i
        raise "Invalid system process id #{id}" unless @id > 0 && @id < @@maxpid
      end

      def procpath(field = nil)
        "/proc/#{@id}/#{field}"
      end

      def method_missing(name, *args)
        unless args.length == 0
          raise ArgumentError.new("wrong number of arguments (#{args.length} for 0)")
        end
        with_procpath_access_failure_handled('') { File.read(procpath(name.to_s)) }
      end

      def exe
        with_procpath_access_failure_handled('') { File.readlink(procpath('exe')) }
      end

      def exe_name
        File.basename(exe)
      end

      def uid
        with_procpath_access_failure_handled { File.stat(procpath('mem')).uid }
      end

      def user
        Etc.getpwuid(uid || 0).name
      end

      def mem_usage_rss
        statm.strip.split(/\s+/)[1].to_i * Etc.sysconf(Etc::SC_PAGESIZE)
      end
      def mem_usage_virt
        statm.strip.split(/\s+/)[0].to_i * Etc.sysconf(Etc::SC_PAGESIZE)
      end
      alias mem_usage mem_usage_virt

      private

      def with_procpath_access_failure_handled(fallback_result = nil)
        yield
      rescue Errno::ENOENT # ignore kernel threads
        fallback_result
      rescue SystemCallError => e # report and ignore
        Cloudscopes.log_error("Error accessing process #{@id}.", e)
        fallback_result
      end
    end

    def list
      list = Dir["/proc/[0-9]*[0-9]"].collect{|dir| SystemProcess.new(File.basename(dir).to_i) }
      list.define_singleton_method(:method_missing) do |name, *args|
        case name.to_s
        when /^by_(.*)/
          field = $1.to_sym
          unless args.length == 1
            raise ArgumentError.new("wrong number of arguments (#{args.length} for 1)")
          end
          select do |ps|
            case ps.send(field)
            when args.first
              true
            else
              false
            end
          end
        else
          raise NoMethodError.new("No such method #{name}",name)
        end
      end
      list
    end

  end

end

