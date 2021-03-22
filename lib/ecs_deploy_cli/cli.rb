module EcsDeployCli
  class CLI < Thor
    desc "validate", "Validates your ECSFile"
    option :file, default: 'ECSFile'
    def validate
      @parser = load(options[:file])
      @parser.validate!
      puts "Your ECSFile looks fine! 🎉"
    end

    desc "version", "Updates all services defined in your ECSFile"
    def version
      puts "ECS Deploy CLI Version #{EcsDeployCli::VERSION}."
    end

    desc "deploy-services", "Updates all services defined in your ECSFile"
    option :file, default: 'ECSFile'
    option :timeout, type: :numeric, default: 500
    def deploy_services
      @parser = load(options[:file])
      runner.update_services! timeout: options[:timeout]
    end

    desc "deploy-service", "Updates a single service defined in your ECSFile"
    option :file, default: 'ECSFile'
    option :timeout, type: :numeric, default: 500
    def deploy_service(name)
      @parser = load(options[:file])
      runner.update_services! service: name, timeout: options[:timeout]
    end

    desc "deploy-scheduled-tasks", "Updates all scheduled tasks defined in your ECSFile"
    option :file, default: 'ECSFile'
    def deploy_scheduled_tasks
      @parser = load(options[:file])
      runner.update_crons!
    end

    desc "ssh", "Connects to ECS instance via SSH"
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
