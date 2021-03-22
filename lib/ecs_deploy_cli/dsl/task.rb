# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Task
      include AutoOptions

      def initialize(name, config)
        @config = config
        _options[:family] = name.to_s
      end

      def containers(*containers)
        @containers = containers
      end

      def cpu(value)
        @cpu = value.to_s
      end

      def memory(value)
        @memory = value.to_s
      end

      def tag(key, value)
        (_options[:tags] ||= []) << { key: key, value: value }
      end

      def volume(value)
        (_options[:volumes] ||= []) << value
      end

      def execution_role(name)
        _options[:execution_role_arn] = "arn:aws:iam::#{@config[:aws_profile_id]}:role/#{name}"
      end

      def as_definition(containers)
        {
          container_definitions: containers.values_at(*@containers),
          execution_role_arn: "arn:aws:iam::#{@config[:aws_profile_id]}:role/ecsTaskExecutionRole",
          requires_compatibilities: ['EC2'],
          placement_constraints: [],
          cpu: @cpu,
          memory: @memory,
          volumes: [],
          network_mode: nil
        }.merge(_options)
      end
    end
  end
end
