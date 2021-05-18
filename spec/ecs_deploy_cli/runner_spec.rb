# frozen_string_literal: true

require 'spec_helper'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-ec2'
require 'aws-sdk-ssm'
require 'aws-sdk-cloudformation'

describe EcsDeployCli::Runner do
  context 'defines task data' do
    let(:parser) { EcsDeployCli::DSL::Parser.load('spec/support/ECSFile') }
    subject { described_class.new(parser) }
    let(:mock_cf_client) { Aws::CloudFormation::Client.new(stub_responses: true) }
    let(:mock_ssm_client) { Aws::SSM::Client.new(stub_responses: true) }
    let(:mock_ecs_client) { Aws::ECS::Client.new(stub_responses: true) }
    let(:mock_ec2_client) { Aws::EC2::Client.new(stub_responses: true) }
    let(:mock_cwe_client) do
      Aws::CloudWatchEvents::Client.new(stub_responses: true)
    end

    context '#validate!' do
      it 'fails on missing params' do
        expect { subject.validate! }.to raise_error('Missing required parameter aws_profile_id')
      end

      context 'with a minimal set of options' do
        let(:parser) { EcsDeployCli::DSL::Parser.load('spec/support/ECSFile.minimal') }
        it 'fails on missing params' do
          mock_ecs_client.stub_responses(:describe_clusters, { clusters: [{ cluster_arn: 'arn:xxx', cluster_name: 'yourproject-cluster' }] })
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
          subject.validate!
        end
      end

      context 'with envs set' do
        around(:each) do |example|
          ENV['AWS_PROFILE_ID'] = '123123123'
          ENV['AWS_REGION'] = 'us-east-1'
          example.run
          ENV['AWS_PROFILE_ID'] = nil
          ENV['AWS_REGION'] = nil
        end

        it 'fails on missing cluster' do
          mock_ecs_client.stub_responses(:describe_clusters, { failures: [{ arn: 'arn:xxx', reason: 'MISSING' }] })
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
          expect { subject.validate! }.to raise_error('No such cluster yourproject-cluster.')
        end

        it 'fails on missing service' do
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

          mock_ecs_client.stub_responses(:describe_clusters, { clusters: [{ cluster_arn: 'arn:xxx', cluster_name: 'yourproject-cluster' }] })
          mock_ecs_client.stub_responses(:describe_services, { services: [], failures: [{}] })

          expect { subject.validate! }.to raise_error('No such service yourproject-service.')
        end

        it 'fails on missing crons' do
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cwe_client).at_least(:once).and_return(mock_cwe_client)
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

          mock_ecs_client.stub_responses(:describe_clusters, { clusters: [{ cluster_arn: 'arn:xxx', cluster_name: 'yourproject-cluster' }] })
          mock_ecs_client.stub_responses(:describe_services, { services: [{ service_arn: 'arn:xxx', service_name: 'yourproject-service' }] })

          expect { subject.validate! }.to raise_error('No such cron scheduled_emails.')
        end

        it 'makes API calls to check if everything is there' do
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
          expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cwe_client).at_least(:once).and_return(mock_cwe_client)

          mock_ecs_client.stub_responses(:describe_clusters, { clusters: [{ cluster_arn: 'arn:xxx', cluster_name: 'yourproject-cluster' }] })
          mock_cwe_client.stub_responses(:list_targets_by_rule, { targets: [{ id: '123', arn: 'arn:123' }] })
          mock_ecs_client.stub_responses(:describe_services, { services: [{ service_arn: 'arn:xxx', service_name: 'yourproject-service' }] })

          subject.validate!
        end
      end
    end

    context 'with envs set' do
      around(:each) do |example|
        ENV['AWS_PROFILE_ID'] = '123123123'
        ENV['AWS_REGION'] = 'us-east-1'
        example.run
        ENV['AWS_PROFILE_ID'] = nil
        ENV['AWS_REGION'] = nil
      end

      it '#setup!' do
        mock_ssm_client.stub_responses(:get_parameter, {
                                         parameter: {
                                           name: '/aws/service/ecs/optimized-ami/amazon-linux-2/recommended',
                                           type: 'String',
                                           value: '{"schema_version":1,"image_name":"amzn2-ami-ecs-hvm-2.0.20210331-x86_64-ebs","image_id":"ami-03bbf53329af34379","os":"Amazon Linux 2","ecs_runtime_version":"Docker version 19.03.13-ce","ecs_agent_version":"1.51.0"}'
                                         }
                                       })

        allow(mock_cf_client).to receive(:wait_until)
        allow(mock_ecs_client).to receive(:create_service)

        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ssm_client).at_least(:once).and_return(mock_ssm_client)
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cf_client).at_least(:once).and_return(mock_cf_client)

        subject.setup!
      end

      it '#ssh' do
        expect(mock_ecs_client).to receive(:list_container_instances).and_return({ container_instance_arns: ['arn:123123'] })
        expect(mock_ecs_client).to receive(:describe_container_instances).and_return(double(container_instances: [double(ec2_instance_id: 'i-123123')]))

        expect(mock_ec2_client).to receive(:describe_instances)
          .with(instance_ids: ['i-123123'])
          .and_return(
            double(reservations: [
                     double(instances: [double(public_dns_name: 'test.com')])
                   ])
          )

        expect(Process).to receive(:fork) do |&block|
          block.call
        end
        expect(Process).to receive(:wait)

        expect_any_instance_of(EcsDeployCli::Runners::SSH).to receive(:exec).with('ssh ec2-user@test.com')
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ec2_client).at_least(:once).and_return(mock_ec2_client)

        subject.ssh
      end

      it '#diff' do
        mock_ecs_client.stub_responses(:describe_task_definition)
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

        expect(EcsDeployCli.logger).to receive(:info).at_least(:once) do |message|
          puts message
        end

        expect { subject.diff }.to output(/Task: yourproject/).to_stdout
      end

      it '#run_task!' do
        mock_ecs_client.stub_responses(:register_task_definition, { task_definition: { family: 'some', revision: 1, task_definition_arn: 'arn:task:eu-central-1:xxxx' } })

        mock_cwe_client.stub_responses(:run_task)

        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

        subject.run_task!('yourproject-cron', launch_type: 'FARGATE', security_groups: [], subnets: [])
      end

      it '#update_crons!' do
        mock_ecs_client.stub_responses(:register_task_definition, { task_definition: { family: 'some', revision: 1, task_definition_arn: 'arn:task:eu-central-1:xxxx' } })

        mock_cwe_client.stub_responses(:list_targets_by_rule, { targets: [{ id: '123', arn: 'arn:123' }] })

        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)
        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cwe_client).at_least(:once).and_return(mock_cwe_client)

        subject.update_crons!
      end

      it '#update_services!' do
        expect(mock_ecs_client).to receive(:register_task_definition).at_least(:once).and_return({ task_definition: { family: 'some', revision: '1' } })
        expect(mock_ecs_client).to receive(:update_service).with(
          cluster: 'yourproject-cluster',
          service: 'yourproject-service',
          task_definition: 'some:1'
        )
        expect(mock_ecs_client).to receive(:wait_until)

        expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

        subject.update_services!
      end
    end
  end
end
