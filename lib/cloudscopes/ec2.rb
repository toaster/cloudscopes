require 'json'
require 'net/http'

module Cloudscopes
  class Ec2
    METADATA_BASE_URL = 'http://169.254.169.254/latest/meta-data'.freeze
    ECS_TASK_METADATA_BASE_URL = 'http://169.254.170.2/v2'.freeze

    def within_ecs_container?
      ecs_task_metadata != nil
    end

    def ecs_cluster
      @@ecs_cluster ||=
          if within_ecs_container?
            ecs_task_metadata['Cluster'].split('/').last
          else
            ENV['ECS_CLUSTER']
          end
    end

    def ecs_task
      if within_ecs_container?
        @@ecs_task ||= ecs_task_metadata['TaskARN'].split('/').last
      end
    end

    def availability_zone
      @@az ||=
        if within_ecs_container?
          ecs_task_metadata['Cluster'].split(':')[3]
        else
          Net::HTTP.get(URI("#{METADATA_BASE_URL}/placement/availability-zone"))
        end
    end

    def instance_id
      unless within_ecs_container?
        @@instanceid ||= Net::HTTP.get(URI("#{METADATA_BASE_URL}/instance-id"))
      end
    end

    private

    def ecs_task_metadata
      unless defined? @@ecs_task_metadata
        response = Net::HTTP.get_response(URI("#{ECS_TASK_METADATA_BASE_URL}/metadata"))
        @@ecs_task_metadata =
            if response.code == "200"
              Cloudscopes.log.info("Running within ECS task.")
              JSON.parse(response.body)
            else
              Cloudscopes.log.info(
                  "Not running within ECS task: #{response.code} - #{response.body}")
              nil
            end
      end
      @@ecs_task_metadata
    end
  end
end
