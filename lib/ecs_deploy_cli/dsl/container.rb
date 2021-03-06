# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Container
      include AutoOptions

      allowed_options :image, :cpu, :working_directory

      def initialize(name, config)
        @config = config
        _options[:name] = name.to_s
      end

      def command(*command)
        _options[:command] = command
      end

      def load_envs(name)
        _options[:environment] = (_options[:environment] || []) + YAML.safe_load(File.open(name), symbolize_names: true)
      end

      def env(key:, value:)
        (_options[:environment] ||= []) << { name: key, value: value }
      end

      def secret(key:, value:)
        (_options[:secrets] ||= []) << { name: key, value_from: "arn:aws:ssm:#{@config[:aws_region]}:#{@config[:aws_profile_id]}:parameter/#{value}" }
      end

      def expose(**options)
        (_options[:port_mappings] ||= []) << options
      end

      def memory(limit:, reservation:)
        _options[:memory] = limit
        _options[:memory_reservation] = reservation
      end

      def merge(other)
        other_options = other._options
        other_options.delete(:name)
        _options.merge!(other_options)
      end

      def cloudwatch_logs(value)
        _options[:log_configuration] = {
          log_driver: 'awslogs',
          options: {
            'awslogs-group' => "/ecs/#{value}",
            'awslogs-stream-prefix' => 'ecs',
            'awslogs-region' => @config[:aws_region]
          }
        }
      end

      def as_definition
        {
          cpu: 0,
          mount_points: [],
          port_mappings: [],
          volumes_from: [],
          memory_reservation: nil,
          essential: true
        }.merge(_options)
      end
    end
  end
end
