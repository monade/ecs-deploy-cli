require 'spec_helper'

describe EcsDeployCli::Container do

  it 'defines data' do
    container = described_class.new('test', { aws_profile_id: '123123' })
  end
end
