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

      protected

      def _update_task(definition)
        ecs_client.register_task_definition(
          definition
        ).to_h[:task_definition]
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

      def config
        @parser.config
      end
    end
  end
end
