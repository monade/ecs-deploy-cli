# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class UpdateServices < Base
      def run!(service: nil, timeout: 500)
        services, resolved_tasks = @parser.resolve

        services.each do |service_name, service_definition|
          next if !service.nil? && service != service_name

          task_definition = _update_task resolved_tasks[service_definition.options[:task]]
          task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

          ecs_client.update_service(
            cluster: config[:cluster],
            service: service_name,
            task_definition: task_name
          )
          wait_for_deploy(service_name, task_name, timeout: timeout)
          EcsDeployCli.logger.info "Deployed service \"#{service_name}\"!"
        end
      end

      private

      def wait_for_deploy(service_name, task_name, timeout:)
        wait_data = { cluster: config[:cluster], services: [service_name] }

        started_at = Time.now
        ecs_client.wait_until(
          :services_stable, wait_data,
          max_attempts: nil,
          before_wait: lambda { |_, response|
            deployments = response.services.first.deployments
            log_deployments task_name, deployments

            throw :success if deployments.count == 1 && deployments[0].task_definition.end_with?(task_name)
            throw :failure if Time.now - started_at > timeout
          }
        )
      end

      def log_deployments(task_name, deployments)
        EcsDeployCli.logger.info "Waiting for task: #{task_name} to become ok."
        EcsDeployCli.logger.info 'Deployment status:'
        deployments.each do |deploy|
          EcsDeployCli.logger.info "[#{deploy.status}] task=#{deploy.task_definition.split('/').last}, "\
                                   "desired_count=#{deploy.desired_count}, pending_count=#{deploy.pending_count}, running_count=#{deploy.running_count}, failed_tasks=#{deploy.failed_tasks}"
        end
        EcsDeployCli.logger.info ''
      end
    end
  end
end
