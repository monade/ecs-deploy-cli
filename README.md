[![Build Status](https://travis-ci.org/monade/ecs-deploy-cli.svg?branch=master)](https://travis-ci.org/monade/ecs-deploy-cli)
[![Gem Version](https://badge.fury.io/rb/ecs_deploy_cli.svg)](https://badge.fury.io/rb/ecs_deploy_cli)

# ECS Deploy CLI

A CLI + DSL to simplify deployments on AWS [Elastic Container Service](https://aws.amazon.com/it/ecs/).

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

# Defining the cluster name. The block data is for the cluster creation configuration.
cluster 'yourproject-cluster' do
  # Default instance type
  instance_type 't3.small'
  # A keypair with this name must exist in your account
  keypair_name 'test'

  # This creates a new VPC in your region. You can also use an existing one.
  vpc do
    availability_zones 'eu-central-1a', 'eu-central-1b', 'eu-central-1c'
  end
end

# This is used as a template for the next two containers, it will not be used inside a task
container :base_container do
  image "#{ENV['REPO_URL']}:#{ENV['CURRENT_VERSION']}"
  load_envs 'envs/base.yml'
  load_envs 'envs/production.yml'
  env key: 'MANUAL_ENV', value: '123'
  secret key: 'SUPER_SECRET_VARIABLE', value: 'superSecretKey' # Taking the secret from AWS System Manager with name "arn:aws:ssm:__AWS_REGION__:__AWS_PROFILE_ID__:parameter/superSecretKey"
  working_directory '/app'
   # Configuring cloudwatch logs. It automatically creates a log group `/ecs/yourproject`
  cloudwatch_logs 'yourproject'
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

  # You can also link an existing load balancer to a task, for instance:
  # load_balancer :'yourproject-load-balancer' do
  #   target_group_arn 'loader-target-group/123abc'
  #   container_name :web
  #   container_port 3000
  # end
end

# A task for cron jobs
task :'yourproject-cron' do
  containers :cron
  cpu 256
  memory 1024
  # This is automatically converted to the relative ARN
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

Now you can use the cli commands to control your cluster.

## Use cases

This DSL can be used both to create new clusters or to control/modify existing ones.

If you want to create a new cluster with the configuration defined in your ECSFile, you can run the `ecs-cli setup` command (see reference below).

Otherwise, you can just validate that the ECSFile is correctly defined in a safe way.

There are a couple of commands that help you here:
* `ecs-deploy validate`: checks if the defined cluster and services exist on your AWS account. It also check for errors in your ECSFile.
* `ecs-deploy diff` computes the differences between your ECSFile configuration and your existing cluster configuration, printing them in STDOUT.

## CLI commands

You can find the full command list by running `ecs-deploy help`.

### Validate
```bash
  $ ecs-deploy validate
```

It checks if your ECSFile is valid and if the cluster/services you've defined exist in your account/region.

### Setup
```bash
  $ ecs-deploy setup
```

It creates the cluster and the services as defined in your ECSFile

### Deploy
```bash
  $ ecs-deploy deploy
```
It deploys (a.k.a. updates) all services and scheduled tasks

### Deploy only services
```bash
  $ ecs-deploy deploy-services
```
It runs a deployment just on services

### Deploy only scheduled tasks
```bash
  $ ecs-deploy deploy-scheduled-tasks
```
It runs a deployment just on scheduled tasks

### Diff
```bash
  $ ecs-deploy diff
```
It prints the differences between your local task_definitions and the ones in your AWS account. Useful to debug what has to be updated using `deploy`.

### Run task
```bash
  $ ecs-deploy run-task [task_name] --subnets subnet1,subnet2 --launch-type [FARGATE|EC2] --security-groups sg-123,sg-234
```
It starts a task in the cluster based on a task definition, given a launch type, a security group and/or subnets.

### SSH
```bash
  $ ecs-deploy ssh
```

It connects with SSH to a cluster container instance. If there are more than one, it will prompt which one you want to connect.

You can also filter by task (`--task [YOUR-TASK]`) or by service (`--service [YOUR-SERVICE]`)

*IMPORTANT* You have to open port 22 in your cluster security group to your IP.

## API

You can also use it as an API:
```ruby
require 'ecs_deploy_cli'

parser = EcsDeployCli::DSL::Parser.load('ECSFile')
# This will update all your services and tasks to fit the new configuration
runner = EcsDeployCli::Runner.new(parser)
runner.update_services!
```

### Known issues
- The ecsInstanceRole has to be created manually if missing: https://docs.aws.amazon.com/batch/latest/userguide/instance_IAM_role.html

## TODOs
- Creating the ecsInstanceRole automatically
- Create scheduled tasks on setup
- Navigate through logs (or maybe not: https://github.com/jorgebastida/awslogs)
- Recap cluster status
- More configuration options
