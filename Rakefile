# frozen_string_literal: true

require_relative 'lib/ecs_deploy_cli/version'

namespace :gem do
  task :release do
    desc 'Releases the gem'

    filename = `gem build ecs-deploy-cli.gemspec 2> /dev/null | grep -E 'File:'`.split(' ').last
    puts "Built #{filename}, now releasing..."

    puts `gem push #{filename}`

    puts `git tag -a v#{EcsDeployCli::VERSION} -m "Version #{EcsDeployCli::VERSION}"`
    puts `git push --tags`
  end
end
