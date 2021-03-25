# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class UpdateCrons < Base
      def run!
        _, tasks, crons = @parser.resolve

        crons.each do |cron_name, cron_definition|
          task_definition = tasks[cron_definition[:task_name]]
          raise "Undefined task #{cron_definition[:task_name].inspect} in (#{tasks.keys.inspect})" unless task_definition

          updated_task = _update_task(task_definition)

          current_target = cwe_client.list_targets_by_rule(
            {
              rule: cron_name,
              limit: 1
            }
          ).to_h[:targets].first

          cwe_client.put_rule(
            cron_definition[:rule]
          )

          cwe_client.put_targets(
            rule: cron_name,
            targets: [
              id: current_target[:id],
              arn: current_target[:arn],
              role_arn: current_target[:role_arn],
              input: cron_definition[:input].to_json,
              ecs_parameters: cron_definition[:ecs_parameters].merge(task_definition_arn: updated_task[:task_definition_arn])
            ]
          )
          EcsDeployCli.logger.info "Deployed scheduled task \"#{cron_name}\"!"
        end
      end
    end
  end
end
