require 'spec_helper'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-ec2'

describe EcsDeployCli::Runner do
  context 'defines task data' do
    let(:parser) { EcsDeployCli::DSL::Parser.load('spec/support/ECSFile') }
    subject { described_class.new(parser) }
    let(:mock_ecs_client) { Aws::ECS::Client.new(stub_responses: true) }
    let(:mock_ec2_client) { Aws::EC2::Client.new(stub_responses: true) }
    let(:mock_cwe_client) do
      Aws::CloudWatchEvents::Client.new(stub_responses: true)
    end

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

      it '#ssh' do
        expect(mock_ecs_client).to receive(:list_container_instances).and_return({ container_instance_arns: ['arn:123123'] })
        expect(mock_ecs_client).to receive(:describe_container_instances).and_return(double(container_instances: [double(ec2_instance_id: 'i-123123')]))

        expect(mock_ec2_client).to receive(:describe_instances)
                                   .with(instance_ids: ['i-123123'])
                                   .and_return(
                                     double(reservations: [
                                       double(instances: [double(public_dns_name: 'test.com')])
                                      ]
                                    )
                                   )

        expect(Process).to receive(:fork) do |&block|
          block.call
        end
        expect(Process).to receive(:wait)

        expect(subject).to receive(:exec).with('ssh ec2-user@test.com')
        expect(subject).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
        expect(subject).to receive(:ec2_client).at_least(:once).and_return(mock_ec2_client)

        subject.ssh
      end

      it '#update_crons!' do
        mock_ecs_client.stub_responses(:register_task_definition, { task_definition: { family: 'some', revision: 1, task_definition_arn: 'arn:task:eu-central-1:xxxx' } })

        mock_cwe_client.stub_responses(:list_targets_by_rule, { targets: [{ id: '123', arn: 'arn:123' }] })

        expect(subject).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
        expect(subject).to receive(:cwe_client).at_least(:once).and_return(mock_cwe_client)

        subject.update_crons!
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
