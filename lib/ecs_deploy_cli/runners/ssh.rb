# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class SSH < Base
      def run!
        instance_ids = load_container_instances
        EcsDeployCli.logger.info "Found instances: #{instance_ids.join(', ')}"

        dns_name = load_dns_name_from_instance_ids(instance_ids)
        run_ssh(dns_name)
      end

      private

      def load_dns_name_from_instance_ids(instance_ids)
        response = ec2_client.describe_instances(
          instance_ids: instance_ids
        )

        response.reservations[0].instances[0].public_dns_name
      end

      def load_container_instances
        instances = ecs_client.list_container_instances(
          cluster: config[:cluster]
        ).to_h[:container_instance_arns]

        response = ecs_client.describe_container_instances(
          cluster: config[:cluster],
          container_instances: instances
        )

        response.container_instances.map(&:ec2_instance_id)
      end

      def run_ssh(dns_name)
        EcsDeployCli.logger.info "Connecting to ec2-user@#{dns_name}..."

        Process.fork { exec("ssh ec2-user@#{dns_name}") }
        Process.wait
      end
    end
  end
end
