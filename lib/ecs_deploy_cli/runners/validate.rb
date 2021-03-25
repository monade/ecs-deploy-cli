# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Validate < Base
      def run!
        services, _, crons = @parser.resolve

        validate_cluster!
        validate_services!(services)
        validate_crons!(crons)
      end

      private

      def validate_cluster!
        data = ecs_client.describe_clusters(clusters: [config[:cluster]])

        raise "No such cluster #{config[:cluster]}." if data.to_h[:failures]&.any? || data.to_h[:clusters].length == 0
      rescue Aws::ECS::Errors::ClusterNotFoundException
        raise "No such cluster #{config[:cluster]}."
      end

      def validate_services!(services)
        services&.each do |service_name, _|
          data = ecs_client.describe_services(cluster: config[:cluster], services: [service_name])

          raise "No such service #{service_name}." if data.to_h[:failures]&.any? || data.to_h[:services].length == 0
        end
      end

      def validate_crons!(crons)
        crons&.each do |cron_name, _|
          items = cwe_client.list_targets_by_rule(
            {
              rule: cron_name,
              limit: 1
            }
          )
          raise "No such cron #{cron_name}." if items.targets.empty?
        rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
          raise "No such cron #{cron_name}."
        end
      end
    end
  end
end
