require 'spec_helper'

describe EcsDeployCli::DSL::Parser do
  context 'defines task data' do
    subject { described_class.load('spec/support/ECSFile') }

    # TODO: More tests
    it 'validates required data in a ECSFile' do
      expect { subject.resolve }.to raise_error('Missing required parameter aws_profile_id')
    end

    context 'with all required data available' do
      around(:each) do |example|
        ENV['AWS_PROFILE_ID'] = '123123123'
        ENV['AWS_REGION'] = 'us-east-1'
        example.run
        ENV['AWS_PROFILE_ID'] = nil
        ENV['AWS_REGION'] = nil
      end

      it 'imports the ECSFile' do
        services, tasks = subject.resolve
        expect(services).to include('yourproject-service')
        expect(tasks).to include(:yourproject)
      end
    end
  end
end
