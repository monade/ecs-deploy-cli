# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Service
      include AutoOptions

      def initialize(name, config)
        _options[:service] = name
        @config = config
      end

      def task(name)
        _options[:task] = name
      end

      def options
        _options
      end

      def load_balancer(name, &block)
        @load_balancers ||= []

        load_balancer = LoadBalancer.new(name, @config)
        load_balancer.instance_exec(&block)

        @load_balancers << load_balancer
      end

      def as_definition(task)
        {
          cluster: @config[:cluster],
          service: _options[:service],
          task_definition: task,
          load_balancers: @load_balancers&.map(&:as_definition) || []
        }
      end

      class LoadBalancer
        include AutoOptions
        allowed_options :container_name, :container_port

        def initialize(name, config)
          _options[:load_balancer_name] = name
          @config = config
        end

        def target_group_arn(value)
          _options[:target_group_arn] = "arn:aws:elasticloadbalancing:#{@config[:aws_region]}:#{@config[:aws_profile_id]}:targetgroup/#{value}"
        end

        def as_definition
          _options
        end
      end
    end
  end
end
