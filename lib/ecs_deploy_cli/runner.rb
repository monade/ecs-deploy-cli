module EcsDeployCli
  class Runner
    def initialize(parser)
      @parser = parser
    end

    def validate!
      @parser.resolve
    end

    def update_crons!
      resolved_tasks = @parser.resolve!

      raise NotImplementedError
    end

    def ssh
      # INSTANCE_ARN=$(aws ecs list-container-instances --cluster "$PROJECT_NAME-cluster" --output text | cut -f2)
      # INSTANCE_ID=$(aws ecs describe-container-instances --cluster "$PROJECT_NAME-cluster" --container-instances $INSTANCE_ARN --output text | head -n 1 | cut -f5)

      # INSTANCE_DNS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --output=text | sed -n '2p' | cut -f15)

      instances = ecs_client.list_container_instances(
        cluster: config[:cluster]
      ).to_h[:container_instance_arns]

      instance = instance.first
      ecs_client.describe_container_instances(
        cluster: config[:cluster],
        container_instances: [
          instance
        ]
      )
      raise instance.inspect
    end

    def update_services!(service: nil, timeout: 500)
      services, resolved_tasks = @parser.resolve

      services.each do |service_name, service_definition|
        next if !service.nil? && service != service_name

        task_name = _update_task resolved_tasks[service_definition.options[:task]]

        ecs_client.update_service(
          cluster: config[:cluster],
          service: service_name,
          task_definition: task_name
        )
        wait_for_deploy(service_name, task_name, timeout: timeout)
      end
    end

    private

    def wait_for_deploy(service_name, task_name, timeout:)
      wait_data = { cluster: config[:cluster], services: [service_name] }

      started_at = Time.now
      ecs_client.wait_until(
        :services_stable, wait_data,
        max_attempts: nil,
        before_wait: lambda { |_, response|
          deployments = response.services.first.deployments
          log_deployments task_name, deployments

          throw :success if deployments.count == 1 && deployments[0].task_definition.end_with?(task_name)
          throw :failure if Time.now - started_at > timeout
        }
      )
    end

    def _update_task(definition)
      task_definition = ecs_client.register_task_definition(
        definition
      ).to_h[:task_definition]

      "#{task_definition[:family]}:#{task_definition[:revision]}"
    end

    def log_deployments(task_name, deployments)
      EcsDeployCli.logger.info "Waiting for task: #{task_name} to become ok."
      EcsDeployCli.logger.info "Deployment status:"
      deployments.each do |deploy|
        EcsDeployCli.logger.info "[#{deploy.status}] task=#{deploy.task_definition.split('/').last}, "\
                                 "desired_count=#{deploy.desired_count}, pending_count=#{deploy.pending_count}, running_count=#{deploy.running_count}, failed_tasks=#{deploy.failed_tasks}"
      end
      EcsDeployCli.logger.info ''
    end

    def ecs_client
      @ecs_client ||= Aws::ECS::Client.new(
        profile: ENV.fetch('AWS_PROFILE', 'default'),
        region: config[:aws_region]
      )
    end

    def config
      @parser.config
    end
  end
end
