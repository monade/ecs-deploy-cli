# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class RunTask < Base
      def run!(task, launch_type:, security_groups:, subnets:)
        _, tasks, = @parser.resolve

        task_definition = _update_task tasks[task]
        task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

        ecs_client.run_task(
          cluster: config[:cluster],
          task_definition: task_name,
          network_configuration: {
            awsvpc_configuration: {
              subnets: subnets,
              security_groups: security_groups,
              assign_public_ip: 'ENABLED'
            }
          },
          launch_type: launch_type
        )
      end
    end
  end
end
