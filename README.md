[![Build Status](https://travis-ci.org/monade/ecs-deploy-cli.svg?branch=master)](https://travis-ci.org/monade/ecs-deploy-cli)

# ECS Deploy CLI

A CLI + DSL to simplify deployments on ECS.

It's partial, incomplete and unstable, DON'T use yet.

## Installation

Simply add the gem to your Gemfile

```ruby
  gem 'ecs-deploy-cli', github: 'monade/ecs-deploy-cli'
```

## Usage

First, define a ECSFile in your project, to design your ECS cluster.

**The cluster and the service must be already there!**

Example of a Rails app on ECS:
```ruby
aws_profile_id ENV['AWS_PROFILE_ID']
aws_region ENV['AWS_REGION']

repository ENV['REPO_URL']
version ENV['CURRENT_VERSION']

cluster ''

# This is used as a template for the next two containers, it will not be used inside a task
container :base_container do
  load_envs 'envs/base.yml'
  load_envs 'envs/production.yml'
  secret key: 'RAILS_MASTER_KEY', value: 'railsMasterKey' # Taking the secret from AWS System Manager
  working_directory '/app'
  cloudwatch 'yourproject' # Configuring cloudwatch logs
end

# The rails web application
container :web, extends: :base_container do
  cpu 512
  memory limit: 3584, reservation: 3584
  command 'bundle', 'exec', 'puma', '-C', 'config/puma.rb'

  expose host_port: 0, protocol: 'tcp', container_port: 3000
end

# The rails job worker
container :worker, extends: :base_container do
  cpu 1536
  memory limit: 3584, reservation: 3584
  command 'bundle', 'exec', 'shoryuken', '-C', 'config/shoryuken.yml', '-R'
end

# A container to exec cron jobs
container :cron, extends: :base_container do
  command 'rails', 'runner'
end

# The main task, having two containers
task :yourproject do
  containers :web, :worker
  cpu 2048
  memory 3584

  tag 'product', 'yourproject'
end

# The main service
service :'yourproject-service' do
  task :yourproject
end

# A task for cron jobs
task :'yourproject-cron' do
  containers :cron
  cpu 256
  memory 1024

  tag 'product', 'yourproject'
end

# Scheduled tasks using Cloudwatch Events / Eventbridge
cron :scheduled_emails do
  task :'yourproject-cron' do
    # Overrides
    container :web do
      command 'rails', 'cron:exec'
    end
  end
  # Examples:
  # every 1.hour
  run_at '0 * * * ? *'
end
```

Now create your deploy script:
```ruby
require 'ecs_deploy_cli'

configuration = EcsDeployCli::FileParser.load('ECSFile')
# This will update all your services and tasks to fit the new configuration
configuration.apply!
```

### TODOs

- Scheduled tasks implementation
- More configuration options
- Create the service if not present
- An actual CLI using Thor
- Specs
