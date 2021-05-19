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
        @tasks ||= {}.with_indifferent_access
        @tasks[task] = Task.new(task, config)
        @tasks[task].instance_exec(&block)
      end

      def service(name, &block)
        @services ||= {}.with_indifferent_access
        @services[name.to_s] = Service.new(name, config)
        @services[name.to_s].instance_exec(&block)
      end

      def cron(name, &block)
        @crons ||= {}.with_indifferent_access
        @crons[name] = Cron.new(name, config)
        @crons[name].instance_exec(&block)
      end

      def cluster(name, &block)
        config[:cluster] = name
        @cluster ||= {}.with_indifferent_access
        @cluster = Cluster.new(name, config)
        @cluster.instance_exec(&block) if block
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
        resolved_containers = (@containers || {}).transform_values(&:as_definition)
        resolved_tasks = (@tasks || {}).transform_values { |t| t.as_definition(resolved_containers) }
        resolved_crons = (@crons || {}).transform_values { |t| t.as_definition(resolved_tasks) }
        resolved_cluster = @cluster.as_definition
        [@services, resolved_tasks, resolved_crons, resolved_cluster]
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
