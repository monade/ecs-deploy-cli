# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class UpdateCrons < Base
      def run!
        _, tasks, crons = @parser.resolve

        crons.each do |cron_name, cron_definition|
          task_definition = tasks[cron_definition[:task_name]]
          unless task_definition
            raise "Undefined task #{cron_definition[:task_name].inspect} in (#{tasks.keys.inspect})"
          end

          updated_task = _update_task(task_definition)

          current_target = load_or_init_target(cron_name)

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

      private

      def load_or_init_target(cron_name)
        cwe_client.list_targets_by_rule({ rule: cron_name, limit: 1 }).to_h[:targets].first
      rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
        {
          id: cron_name,
          arn: "arn:aws:ecs:#{config[:aws_region]}:#{config[:aws_profile_id]}:cluster/#{config[:cluster]}",
          role_arn: "arn:aws:iam::#{config[:aws_profile_id]}:role/ecsEventsRole"
        }
      end
    end
  end
end
