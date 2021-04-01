# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Status < Base
      def run!(service)
        services, = @parser.resolve

        services.each do |service_name, service_definition|
          next if !service.nil? && service != service_name

          # task_definition = _update_task resolved_tasks[service_definition.options[:task]]
          # task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

          puts ecs_client.describe_service(
            cluster: config[:cluster],
            service: service_name
          )
        end
      end
    end
  end
end
