# frozen_string_literal: true

require 'active_support'
require 'rspec'
require 'ecs_deploy_cli'

I18n.enforce_available_locales = false
RSpec::Expectations.configuration.warn_about_potential_false_positives = false

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|

end
