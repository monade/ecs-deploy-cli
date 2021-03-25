# frozen_string_literal: true

require 'ecs_deploy_cli/runners/base'
require 'ecs_deploy_cli/runners/ssh'
require 'ecs_deploy_cli/runners/validate'
require 'ecs_deploy_cli/runners/diff'
require 'ecs_deploy_cli/runners/update_crons'
require 'ecs_deploy_cli/runners/update_services'
require 'ecs_deploy_cli/runners/run_task'

module EcsDeployCli
  class Runner
    def initialize(parser)
      @parser = parser
    end

    def validate!
      EcsDeployCli::Runners::Validate.new(@parser).run!
    end

    def update_crons!
      EcsDeployCli::Runners::UpdateCrons.new(@parser).run!
    end

    def run_task!(task_name, launch_type:, security_groups:, subnets:)
      EcsDeployCli::Runners::RunTask.new(@parser).run!(task_name, launch_type: launch_type, security_groups: security_groups, subnets: subnets)
    end

    def ssh
      EcsDeployCli::Runners::SSH.new(@parser).run!
    end

    def diff
      EcsDeployCli::Runners::Diff.new(@parser).run!
    end

    def update_services!(service: nil, timeout: 500)
      EcsDeployCli::Runners::UpdateServices.new(@parser).run!(service: service, timeout: timeout)
    end

    private

    def _update_task(definition)
      ecs_client.register_task_definition(
        definition
      ).to_h[:task_definition]
    end
  end
end
