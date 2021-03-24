require 'yaml'
require 'logger'
require 'thor'
require 'aws-sdk-ecs'
require 'active_support/core_ext/hash/indifferent_access'

module EcsDeployCli
  def self.logger
    @logger ||= begin
      logger = Logger.new(STDOUT)
      logger.formatter = proc { |severity, datetime, progname, msg|
        "#{msg}\n"
      }
      logger.level = Logger::INFO
      logger
    end
  end

  def self.logger=(value)
    @logger = value
  end
end

require 'ecs_deploy_cli/version'
require 'ecs_deploy_cli/dsl/auto_options'
require 'ecs_deploy_cli/dsl/container'
require 'ecs_deploy_cli/dsl/task'
require 'ecs_deploy_cli/dsl/cron'
require 'ecs_deploy_cli/dsl/service'
require 'ecs_deploy_cli/dsl/parser'
require 'ecs_deploy_cli/runner'
require 'ecs_deploy_cli/cli'
