[![Build Status](https://travis-ci.org/monade/ecs-deploy-cli.svg?branch=master)](https://travis-ci.org/monade/ecs-deploy-cli)

# ECS Deploy CLI

A CLI + DSL to simplify deployments on ECS.

It's partial, incomplete and unstable. Use it at your own risk.

## Motivation

Once you've configured your cluster on ECS, running Continous Deployment is not that easy.

A simple deployment requires:
* Upload the Docker image
* Update all your tasks
* Update all services
* Update eventual Scheduled Tasks manually

We had some struggle with the official `ecs-cli` approach related with static compose files, requiring a lot of repetition (and potential errors) while defining tasks and envs.

Moreover, you might want some business logic about how your cluster should be configured, like using ENV files, or switch between stages (production / staging), or adjusting container requirements based on external variables.

So, why not creating a DSL built on top of our favourite language? <3

## Installation

You can install this gem globally
```bash
  $ gem install ecs-deploy-cli
```

Or add the gem to your Gemfile:

```ruby
  gem 'ecs-deploy-cli'
```

## Usage

First, define a ECSFile in your project, to design your ECS cluster.

**The cluster and the service must be already there!**

Example of a Rails app on ECS:
```ruby
aws_region ENV.fetch('AWS_REGION', 'eu-central-1')

# Used to create ARNs
aws_profile_id '123123'

# Defining the cluster name
cluster 'yourproject-cluster'

# This is used as a template for the next two containers, it will not be used inside a task
container :base_container do
  image "#{ENV['REPO_URL']}:#{ENV['CURRENT_VERSION']}"
  load_envs 'envs/base.yml'
  load_envs 'envs/production.yml'
  env key: 'MANUAL_ENV', value: '123'
  secret key: 'RAILS_MASTER_KEY', value: 'railsMasterKey' # Taking the secret from AWS System Manager with name "arn:aws:ssm:__AWS_REGION__:__AWS_PROFILE_ID__:parameter/railsMasterKey"
  working_directory '/app'
  cloudwatch_logs 'yourproject' # Configuring cloudwatch logs
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

  requires_compatibilities ['FARGATE']
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
  execution_role 'ecsTaskExecutionRole'
  network_mode 'awsvpc'

  tag 'product', 'yourproject'
end

# Scheduled tasks using Cloudwatch Events / Eventbridge
cron :scheduled_emails do
  task :'yourproject-cron' do
    # Container overrides
    container :cron do
      command 'rails', 'cron:exec'
    end
  end
  subnets 'subnet-123123'
  launch_type 'FARGATE'
  # Task role override:
  # task_role 'somerole'

  # Examples:
  # run_every '2 hours'
  run_at '0 * * * ? *'
end
```

Now you can run the commands from the CLI.

For instance, you can run deploy:
```bash
  $ ecs-deploy deploy
```

## CLI commands

You can find the full command list by running `ecs-deploy help`.

Check if your ECSFile is valid
```bash
  $ ecs-deploy validate
```

Deploy all services and scheduled tasks
```bash
  $ ecs-deploy deploy
```

Deploy just services
```bash
  $ ecs-deploy deploy-services
```

Deploy just scheduled tasks
```bash
  $ ecs-deploy deploy-scheduled-tasks
```

Run SSH on a cluster container instance:
```bash
  $ ecs-deploy ssh
```

## API

You can also use it as an API:
```ruby
require 'ecs_deploy_cli'

parser = EcsDeployCli::DSL::Parser.load('ECSFile')
# This will update all your services and tasks to fit the new configuration
runner = EcsDeployCli::Runner.new(parser)
runner.update_services!
```

## TODOs

- Create cloudwatch logs group if it doesn't exist yet
- Create the service if not present?
- Create scheduled tasks if not present?
- Navigate through logs
- Recap cluster status
- More configuration options
