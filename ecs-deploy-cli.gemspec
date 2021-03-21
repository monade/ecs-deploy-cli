# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'ecs_deploy_cli/version'

Gem::Specification.new do |s|
  s.name        = 'ecs_deploy_cli'
  s.version     = EcsDeployCli::VERSION
  s.date        = '2021-03-31'
  s.summary     = "A Command line interface to make ECS deploys more simple"
  s.description = "A Command line interface to make ECS deploys more simple"
  s.authors     = ['Mònade']
  s.email       = 'team@monade.io'
  s.files = Dir['lib/**/*']
  s.test_files = Dir['spec/**/*']
  s.required_ruby_version = '>= 2.5.0'
  s.homepage    = 'https://rubygems.org/gems/ecs_deploy_cli'
  s.license     = 'MIT'
  s.add_dependency 'activesupport', ['>= 5', '< 7']
  s.add_dependency 'aws-sdk-ecs'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rubocop'
end
