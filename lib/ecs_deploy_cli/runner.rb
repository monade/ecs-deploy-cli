module EcsDeployCli
  class Runner
    def initialize(parser)
      @parser = parser
    end

    def validate!
      @parser.resolve
    end

    def update_crons!
      _, tasks, crons = @parser.resolve

      crons.each do |cron_name, cron_definition|
        task_definition = tasks[cron_definition[:task_name]]
        raise "Undefined task #{cron_definition[:task_name].inspect} in (#{tasks.keys.inspect})" unless task_definition

        updated_task = _update_task(task_definition)

        current_target = cwe_client.list_targets_by_rule(
          {
            rule: cron_name,
            limit: 1
          }
        ).to_h[:targets].first

        cwe_client.put_rule(
          cron_definition[:rule]
        )

        cwe_client.put_targets(
          rule: cron_name,
          targets: [
            id: current_target[:id],
            arn: current_target[:arn],
            role_arn: current_target[:role_arn],
            input: cron_definition[:input].to_json,
            ecs_parameters: cron_definition[:ecs_parameters].merge(task_definition_arn: updated_task[:task_definition_arn])
          ]
        )
        EcsDeployCli.logger.info "Deployed scheduled task \"#{cron_name}\"!"
      end
    end

    def ssh
      instances = ecs_client.list_container_instances(
        cluster: config[:cluster]
      ).to_h[:container_instance_arns]

      response = ecs_client.describe_container_instances(
        cluster: config[:cluster],
        container_instances: instances
      )

      EcsDeployCli.logger.info "Found instances: #{response.container_instances.map(&:ec2_instance_id).join(', ')}"

      response = ec2_client.describe_instances(
        instance_ids: response.container_instances.map(&:ec2_instance_id)
      )

      dns_name = response.reservations[0].instances[0].public_dns_name
      EcsDeployCli.logger.info "Connecting to ec2-user@#{dns_name}..."

      Process.fork { exec("ssh ec2-user@#{dns_name}") }
      Process.wait
    end

    def update_services!(service: nil, timeout: 500)
      services, resolved_tasks = @parser.resolve

      services.each do |service_name, service_definition|
        next if !service.nil? && service != service_name

        task_definition = _update_task resolved_tasks[service_definition.options[:task]]
        task_name = "#{task_definition[:family]}:#{task_definition[:revision]}"

        ecs_client.update_service(
          cluster: config[:cluster],
          service: service_name,
          task_definition: "#{task_definition[:family]}:#{task_name}"
        )
        wait_for_deploy(service_name, task_name, timeout: timeout)
        EcsDeployCli.logger.info "Deployed service \"#{service_name}\"!"
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
      ecs_client.register_task_definition(
        definition
      ).to_h[:task_definition]
    end

    def log_deployments(task_name, deployments)
      EcsDeployCli.logger.info "Waiting for task: #{task_name} to become ok."
      EcsDeployCli.logger.info 'Deployment status:'
      deployments.each do |deploy|
        EcsDeployCli.logger.info "[#{deploy.status}] task=#{deploy.task_definition.split('/').last}, "\
                                 "desired_count=#{deploy.desired_count}, pending_count=#{deploy.pending_count}, running_count=#{deploy.running_count}, failed_tasks=#{deploy.failed_tasks}"
      end
      EcsDeployCli.logger.info ''
    end

    def ec2_client
      @ec2_client ||= begin
        require 'aws-sdk-ec2'
        Aws::EC2::Client.new(
          profile: ENV.fetch('AWS_PROFILE', 'default'),
          region: config[:aws_region]
        )
      end
    end

    def ecs_client
      @ecs_client ||= Aws::ECS::Client.new(
        profile: ENV.fetch('AWS_PROFILE', 'default'),
        region: config[:aws_region]
      )
    end

    def cwe_client
      @cwe_client ||= begin
        require 'aws-sdk-cloudwatchevents'
        Aws::CloudWatchEvents::Client.new(
          profile: ENV.fetch('AWS_PROFILE', 'default'),
          region: config[:aws_region]
        )
      end
    end

    def config
      @parser.config
    end
  end
end
