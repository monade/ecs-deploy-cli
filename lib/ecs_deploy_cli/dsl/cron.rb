# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Cron
      include AutoOptions

      def initialize(name, config)
        _options[:name] = name
        @config = config
      end

      def task(name, &block)
        _options[:task] = Task.new(name.to_s, @config)
        _options[:task].instance_exec(&block)
      end

      def run_at(cron_expression)
        @cron_expression = "cron(#{cron_expression})"
      end

      def run_every(interval)
        @every = "rate(#{interval})"
      end

      def task_role(role)
        _options[:task_role] = "arn:aws:iam::#{@config[:aws_profile_id]}:role/#{role}"
      end

      def subnets(*value)
        _options[:subnets] = value
      end

      def security_groups(*value)
        _options[:security_groups] = value
      end

      def launch_type(value)
        _options[:launch_type] = value
      end

      def assign_public_ip(value)
        _options[:assign_public_ip] = value
      end

      def as_definition(tasks)
        raise 'Missing task definition' unless _options[:task]

        input = { 'containerOverrides' => _options[:task].as_definition }
        input['taskRoleArn'] = _options[:task_role] if _options[:task_role]

        {
          task_name: _options[:task].name,
          rule: {
            name: _options[:name],
            schedule_expression: @cron_expression || @every || raise("Missing schedule expression.")
          },
          input: input,
          ecs_parameters: {
            # task_definition_arn: task_definition[:task_definition_arn],
            task_count: _options[:task_count] || 1,
            launch_type: _options[:launch_type] || raise('Missing parameter launch_type'),
            network_configuration: {
              awsvpc_configuration: {
                subnets: _options[:subnets] || raise('Missing parameter subnets'),
                security_groups: _options[:security_groups] || [],
                assign_public_ip: _options[:assign_public_ip] ? 'ENABLED' : 'DISABLED'
              }
            },
            platform_version: _options[:platform_version] || 'LATEST'
          }
        }
      end

      class Task
        include AutoOptions

        attr_reader :name

        def initialize(name, config)
          @name = name
          @config = config
        end

        def container(name, &block)
          container = Container.new(name, @config)
          container.instance_exec(&block)
          (_options[:containers] ||= []) << container
        end

        def as_definition
          # [{"name"=>"cron", "command"=>["rails", "cron:adalytics"]}]
          (_options[:containers] || []).map(&:as_definition)
        end
      end

      class Container < EcsDeployCli::DSL::Container
        def as_definition
          _options.to_h
        end
      end
    end
  end
end
