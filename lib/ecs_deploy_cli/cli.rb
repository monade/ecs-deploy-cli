# frozen_string_literal: true

module EcsDeployCli
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'validate', 'Validates your ECSFile'
    option :file, default: 'ECSFile'
    def validate
      @parser = load(options[:file])
      runner.validate!
      puts 'Your ECSFile looks fine! 🎉'
    end

    desc 'diff', 'Check differences between task definitions'
    option :file, default: 'ECSFile'
    def diff
      @parser = load(options[:file])
      runner.diff
    end

    desc 'version', 'Updates all services defined in your ECSFile'
    def version
      puts "ECS Deploy CLI Version #{EcsDeployCli::VERSION}."
    end

    desc 'setup', 'Setups the cluster'
    option :file, default: 'ECSFile'
    option :timeout, type: :numeric, default: 500
    def setup
      @parser = load(options[:file])
      runner.setup!
    end

    desc 'deploy-scheduled-tasks', 'Updates all scheduled tasks defined in your ECSFile'
    option :file, default: 'ECSFile'
    def deploy_scheduled_tasks
      @parser = load(options[:file])
      runner.update_crons!
    end

    desc 'deploy-services', 'Updates all services defined in your ECSFile'
    option :only
    option :file, default: 'ECSFile'
    option :timeout, type: :numeric, default: 500
    def deploy_services
      @parser = load(options[:file])
      runner.update_services! timeout: options[:timeout], service: options[:only]
    end

    desc 'deploy', 'Updates all services and scheduled tasks at once'
    option :file, default: 'ECSFile'
    option :timeout, type: :numeric, default: 500
    def deploy
      @parser = load(options[:file])
      runner.update_services! timeout: options[:timeout]
      runner.update_crons!
    end

    desc 'run-task NAME', 'Manually runs a task defined in your ECSFile'
    option :launch_type, default: 'FARGATE'
    option :security_groups, default: '', type: :string
    option :subnets, required: true, type: :string
    option :file, default: 'ECSFile'
    def run_task(task_name)
      @parser = load(options[:file])
      runner.run_task!(
        task_name,
        launch_type: options[:launch_type],
        security_groups: options[:security_groups].split(','),
        subnets: options[:subnets].split(',')
      )
    end

    desc 'ssh', 'Connects to ECS instance via SSH'
    option :file, default: 'ECSFile'
    def ssh
      @parser = load(options[:file])
      runner.ssh
    end

    private

    def load(file)
      EcsDeployCli::DSL::Parser.load(file)
    end

    def runner
      @runner ||= EcsDeployCli::Runner.new(@parser)
    end
  end
end
