# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'ecs_deploy_cli/version'

Gem::Specification.new do |s|
  s.name        = 'ecs_deploy_cli'
  s.version     = EcsDeployCli::VERSION
  s.date        = '2021-03-31'
  s.summary     = 'A command line interface to make ECS deployments easier'
  s.description = 'Declare your cluster structure in a ECSFile and use the CLI to run deploys and monitor its status.'
  s.authors     = ['Mònade', 'ProGM']
  s.email       = 'team@monade.io'
  s.files = Dir['lib/**/*']
  s.test_files = Dir['spec/**/*']
  s.required_ruby_version = '>= 2.5.0'
  s.homepage    = 'https://rubygems.org/gems/ecs_deploy_cli'
  s.metadata    = { 'source_code_uri' => 'https://github.com/monade/ecs-deploy-cli' }
  s.license     = 'MIT'
  s.executables << 'ecs-deploy'
  s.add_dependency 'activesupport', ['>= 5', '< 7']
  s.add_dependency 'aws-sdk-cloudformation', '~> 1'
  s.add_dependency 'aws-sdk-cloudwatchevents', '~> 1'
  s.add_dependency 'aws-sdk-ec2', '~> 1'
  s.add_dependency 'aws-sdk-ecs', '~> 1'
  s.add_dependency 'aws-sdk-ssm', '~> 1'
  s.add_dependency 'colorize', '~> 0.8.1'
  s.add_dependency 'hashdiff', '~> 1.0'
  s.add_dependency 'thor', '~> 1.1'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rubocop', '~> 0.93'
end
