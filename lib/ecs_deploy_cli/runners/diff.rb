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

          result = ecs_client.describe_task_definition(task_definition: task_name).to_h

          current = cleanup_source_task(result[:task_definition])
          definition = cleanup_source_task(definition)

          print_diff Hashdiff.diff(current.except(:container_definitions), definition.except(:container_definitions))

          diff_container_definitions(
            current[:container_definitions],
            definition[:container_definitions]
          )

          EcsDeployCli.logger.info '---'
        end
      end

      private

      def diff_container_definitions(first, second)
        first.zip(second).each do |a, b|
          EcsDeployCli.logger.info "Container #{a&.dig(:name) || 'NONE'} <=> #{b&.dig(:name) || 'NONE'}"

          next if !a || !b

          sort_envs! a
          sort_envs! b

          print_diff Hashdiff.diff(a.delete_if { |_, v| v.nil? }, b.delete_if { |_, v| v.nil? })
        end
      end

      def sort_envs!(definition)
        return unless definition[:environment]

        definition[:environment].sort_by! { |e| e[:name] }
      end

      def cleanup_source_task(task)
        task.except(
          :revision, :compatibilities, :status, :registered_at, :registered_by,
          :requires_attributes, :task_definition_arn
        ).delete_if { |_, v| v.nil? }
      end

      def print_diff(diff)
        diff.each do |(op, path, *values)|
          case op
          when '-'
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:red)
          when '+'
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:green)
          else
            EcsDeployCli.logger.info "#{op} #{path} => #{values.join(' ')}".colorize(:yellow)
          end
        end
      end
    end
  end
end
