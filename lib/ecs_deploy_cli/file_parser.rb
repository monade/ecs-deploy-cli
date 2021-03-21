# frozen_string_literal: true

module EcsDeployCli
  class FileParser
    def version(version)
      config[:version] = version
    end

    def aws_profile_id(value)
      config[:aws_profile_id] = value
    end

    def aws_region(value)
      config[:aws_region] = value
    end

    def stage(stage)
      config[:stage] = stage
    end

    def repository(repository)
      config[:repository] = repository
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
      @services[name] = Service.new(name, config)
      @services[name].instance_exec(&block)
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

    def apply!
      ensure_required_params!
      resolved_containers = @containers.transform_values(&:as_definition)
      resolved_tasks = @tasks.transform_values { |t| t.as_definition(resolved_containers) }

      client = Aws::ECS::Client.new(
        profile: ENV.fetch('AWS_PROFILE', 'default'),
        region: config[:aws_region]
      )

      @services.each do |service_name, service|
        task_definition = client.register_task_definition(
          resolved_tasks[service.options[:task]]
        ).to_h[:task_definition]

        task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

        client.update_service(
          cluster: config[:cluster],
          service: service_name.to_s,
          task_definition: task_name
        )

        wait_data = { cluster: config[:cluster], services: [service_name.to_s] }

        started_at = Time.now
        client.wait_until(
          :services_stable, wait_data,
          max_attempts: nil,
          before_wait: lambda { |_, response|
            deployments = response.services.first.deployments
            puts "Waiting for task: #{task_name} to become ok. #{deployments.inspect}"

            throw :success if deployments.count == 1 && deployments[0].task_definition.end_with?(task_name)
            throw :failure if Time.now - started_at > 500
          }
        )
      end
    end

    def ensure_required_params!
      [
        :aws_profile_id, :aws_region, :repository, :version, :cluster
      ].each { |key| raise "Missing required parameter #{key}" unless config[key] }
    end

    def self.load(file)
      result = new
      result.instance_eval(File.read(file))
      result
    end
  end
end
