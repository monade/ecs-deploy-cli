# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class SSH < Base
      def run!(params = {})
        instance_ids = load_container_instances(params)

        instance_id = choose_instance_id(instance_ids)
        dns_name = load_dns_name_from_instance_id(instance_id)
        run_ssh(dns_name)
      end

      private

      def choose_instance_id(instance_ids)
        raise 'No instance found' if instance_ids.empty?
        return instance_ids[0] if instance_ids.length == 1

        instances_selection_text = instance_ids.map.with_index do |instance, index|
          "#{index + 1}) #{instance}"
        end.join("\n")

        EcsDeployCli.logger.info(
          "Found #{instance_ids.count} instances:\n#{instances_selection_text}\nSelect which one you want to access:"
        )

        index = select_index_from_array(instance_ids, retry_message: 'Invalid option. Select which one you want to access:')

        instance_ids[index]
      end

      def select_index_from_array(array, retry_message:)
        while (index = STDIN.gets.chomp)
          if index =~ /\A[1-9][0-9]*\Z/ && (index.to_i - 1) < array.count
            index = index.to_i - 1
            break
          end

          EcsDeployCli.logger.info(retry_message)
        end
        index
      end

      def load_dns_name_from_instance_id(instance_id)
        response = ec2_client.describe_instances(
          instance_ids: [instance_id]
        )

        response.reservations[0].instances[0].public_dns_name
      end

      def load_container_instances(params = {})
        task_arns = ecs_client.list_tasks(
          **params.merge(cluster: config[:cluster])
        ).to_h[:task_arns]

        tasks = ecs_client.describe_tasks(
          tasks: task_arns, cluster: config[:cluster]
        ).to_h[:tasks]

        instances = tasks.map { |task| task[:container_instance_arn] }.uniq
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
