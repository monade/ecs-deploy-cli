# frozen_string_literal: true

module EcsDeployCli
  module Runners
    class Diff < Base
      def run!
        require 'hashdiff'
        require 'colorize'

        _, tasks, = @parser.resolve

        tasks.each do |task_name, definition|
          EcsDeployCli.logger.info '---'
          EcsDeployCli.logger.info "Task: #{task_name}"

          result = ecs_client.describe_task_definition(task_definition: "#{task_name}").to_h

          current = result[:task_definition].except(:revision, :status, :registered_at, :registered_by, :requires_attributes, :task_definition_arn)

          print_diff Hashdiff.diff(current.except(:container_definitions), definition.except(:container_definitions))

          current[:container_definitions].zip(definition[:container_definitions]).each do |a, b|
            EcsDeployCli.logger.info "Container #{a&.dig(:name) || 'NONE'} <=> #{b&.dig(:name) || 'NONE'}"

            print_diff Hashdiff.diff(a, b) if a && b
          end
          EcsDeployCli.logger.info '---'
        end
      end

      def print_diff(diff)
        diff.each do |(op, path, *values)|
          if op == '-'
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:red)
          elsif op == '+'
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:green)
          else
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:light_blue)
          end
        end
      end
    end
  end
end
