require 'spec_helper'

describe EcsDeployCli::Runner do
  context 'defines task data' do
    let(:parser) { EcsDeployCli::DSL::Parser.load('spec/support/ECSFile') }
    subject { described_class.new(parser) }
    let(:mock_ecs_client) { double }

    it '#validate!' do
      expect { subject.validate! }.to raise_error('Missing required parameter aws_profile_id')
    end

    context 'with envs set' do
      around(:each) do |example|
        ENV['AWS_PROFILE_ID'] = '123123123'
        ENV['AWS_REGION'] = 'us-east-1'
        example.run
        ENV['AWS_PROFILE_ID'] = nil
        ENV['AWS_REGION'] = nil
      end

      it '#update_services!' do
        expect(mock_ecs_client).to receive(:register_task_definition).at_least(:once).and_return({ task_definition: { family: 'some', revision: '1' } })
        expect(mock_ecs_client).to receive(:update_service)
        expect(mock_ecs_client).to receive(:wait_until)

        expect(subject).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

        subject.update_services!
      end
    end
  end
end
