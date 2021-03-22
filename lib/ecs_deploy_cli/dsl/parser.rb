# frozen_string_literal: true

module EcsDeployCli
  module DSL
    class Parser
      def aws_profile_id(value)
        config[:aws_profile_id] = value
      end

      def aws_region(value)
        config[:aws_region] = value
      end

      def stage(stage)
        config[:stage] = stage
      end

      def container(container, extends: nil, &block)
        @containers ||= {}
        @containers[container] = Container.new(container, config)
        @containers[container].merge(@containers[extends]) if extends
        @containers[container].instance_exec(&block)
      end

      def task(task, &block)
        @tasks ||= {}
        @tasks[task] = Task.new(task, config)
        @tasks[task].instance_exec(&block)
      end

      def service(name, &block)
        @services ||= {}
        @services[name.to_s] = Service.new(name, config)
        @services[name.to_s].instance_exec(&block)
      end

      def cron(name, &block)
        @crons ||= {}
        @crons[name] = Cron.new(name, config)
        @crons[name].instance_exec(&block)
      end

      def cluster(name)
        config[:cluster] = name
      end

      def config
        @config ||= {}
      end

      def ensure_required_params!
        [
          :aws_profile_id, :aws_region, :cluster
        ].each { |key| raise "Missing required parameter #{key}" unless config[key] }
      end

      def resolve
        resolved_containers = @containers.transform_values(&:as_definition)
        [@services, @tasks.transform_values { |t| t.as_definition(resolved_containers) }]
      end

      def self.load(file)
        result = new
        result.instance_eval(File.read(file))
        result.ensure_required_params!
        result
      end
    end
  end
end
