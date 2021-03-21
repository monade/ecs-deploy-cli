require 'spec_helper'

describe EcsDeployCli::Task do

  it 'defines data' do
    task = EcsDeployCli::Task.new('test', { aws_profile_id: '123123' })
  end
end
