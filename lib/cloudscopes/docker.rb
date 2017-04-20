module Cloudscopes
  class Docker
    def ps(name_filter: nil)
      filter_args = ["--filter", "name=#{name_filter}"] if name_filter
      perform(:ps, '--quiet', *filter_args).split
    end

    def exec(container_id, *cmd)
      perform(:exec, container_id, *cmd)
    end

    private

    # Docker may be called via sudo and this should be very restrictive on the path.
    # So `sudo docker` should not be allowed since this is a security risc.
    def docker_bin
      @@docker_bin ||= `which docker`.strip
    end

    def perform(*args)
      command = []
      unless root?
        command << "sudo"
        command << "--non-interactive"
      end
      command << docker_bin
      args.each {|arg| command << arg.to_s }
      IO.popen(command) {|out| out.read }
    end

    def root?
      unless defined? @root
        @root = current_user == "root"
      end
      @root
    end

    def current_user
      @current_user ||= `id -u -n`.strip
    end
  end
end
