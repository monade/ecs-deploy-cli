# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Base
      def initialize(parser)
        @parser = parser
      end

      def run!
        raise NotImplementedError, 'abstract method'
      end

      def update_task(definition)
        _update_task(definition)
      end

      protected

      def _update_task(definition)
        definition[:container_definitions].each do |container|
          next unless container.dig(:log_configuration, :log_driver) == 'awslogs'

          _create_cloudwatch_logs_if_needed(container.dig(:log_configuration, :options, 'awslogs-group'))
        end

        ecs_client.register_task_definition(
          definition
        ).to_h[:task_definition]
      end

      def _create_cloudwatch_logs_if_needed(prefix)
        log_group = cwl_client.describe_log_groups(log_group_name_prefix: prefix, limit: 1).to_h[:log_groups]
        return if log_group.any?

        cwl_client.create_log_group(log_group_name: prefix)
        cwl_client.put_retention_policy(
          log_group_name: prefix,
          retention_in_days: 14
        )
      end

      def ec2_client
        @ec2_client ||= begin
          require 'aws-sdk-ec2'
          Aws::EC2::Client.new(
            profile: ENV.fetch('AWS_PROFILE', 'default'),
            region: config[:aws_region]
          )
        end
      end

      def ecs_client
        @ecs_client ||= Aws::ECS::Client.new(
          profile: ENV.fetch('AWS_PROFILE', 'default'),
          region: config[:aws_region]
        )
      end

      def cwe_client
        @cwe_client ||= begin
          require 'aws-sdk-cloudwatchevents'
          Aws::CloudWatchEvents::Client.new(
            profile: ENV.fetch('AWS_PROFILE', 'default'),
            region: config[:aws_region]
          )
        end
      end

      def ssm_client
        @cwl_client ||= begin
          require 'aws-sdk-ssm'
          Aws::SSM::Client.new(
            profile: ENV.fetch('AWS_PROFILE', 'default'),
            region: config[:aws_region]
          )
        end
      end

      def cwl_client
        @cwl_client ||= begin
          require 'aws-sdk-cloudwatchlogs'
          Aws::CloudWatchLogs::Client.new(
            profile: ENV.fetch('AWS_PROFILE', 'default'),
            region: config[:aws_region]
          )
        end
      end

      def cf_client
        @cl_client ||= begin
          require 'aws-sdk-cloudformation'
          Aws::CloudFormation::Client.new(
            profile: ENV.fetch('AWS_PROFILE', 'default'),
            region: config[:aws_region]
          )
        end
      end

      def config
        @parser.config
      end
    end
  end
end
