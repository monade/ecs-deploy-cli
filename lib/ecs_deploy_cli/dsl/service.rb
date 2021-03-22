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

      def as_definition(task)
        {
          cluster: @config[:cluster],
          service: service_name,
          task_definition: task
        }
      end
    end
  end
end
