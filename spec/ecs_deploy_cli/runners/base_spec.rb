# frozen_string_literal: true

require 'spec_helper'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-cloudwatchlogs'
require 'aws-sdk-ec2'
require 'aws-sdk-ssm'
require 'aws-sdk-cloudformation'

describe EcsDeployCli::Runners::Base do
  let(:parser) { EcsDeployCli::DSL::Parser.load('spec/support/ECSFile') }
  subject { described_class.new(parser) }
  let(:mock_cf_client) { Aws::CloudFormation::Client.new(stub_responses: true) }
  let(:mock_ssm_client) { Aws::SSM::Client.new(stub_responses: true) }
  let(:mock_ecs_client) { Aws::ECS::Client.new(stub_responses: true) }
  let(:mock_ec2_client) { Aws::EC2::Client.new(stub_responses: true) }
  let(:mock_cwl_client) { Aws::CloudWatchLogs::Client.new(stub_responses: true) }
  let(:mock_cwe_client) do
    Aws::CloudWatchEvents::Client.new(stub_responses: true)
  end

  around(:each) do |example|
    ENV['AWS_PROFILE_ID'] = '123123123'
    ENV['AWS_REGION'] = 'us-east-1'
    example.run
    ENV['AWS_PROFILE_ID'] = nil
    ENV['AWS_REGION'] = nil
  end

  context '#update_task' do
    it 'creates cloud watch logs if missing' do
      _, tasks, = parser.resolve

      expect(mock_cwl_client).to receive(:describe_log_groups).at_least(:once).and_return({ log_groups: [] })
      expect(mock_cwl_client).to receive(:create_log_group).at_least(:once)
      expect(mock_ecs_client).to receive(:register_task_definition).at_least(:once).and_return({ task_definition: { family: 'some', revision: '1' } })

      expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cwl_client).at_least(:once).and_return(mock_cwl_client)
      expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

      subject.update_task(tasks.values.first)
    end

    it 'creates no cloudwatch log group if is already there' do
      _, tasks, = parser.resolve

      expect(mock_cwl_client).to receive(:describe_log_groups).at_least(:once).and_return({ log_groups: [{}] })
      expect(mock_cwl_client).not_to receive(:create_log_group)
      expect(mock_ecs_client).to receive(:register_task_definition).at_least(:once).and_return({ task_definition: { family: 'some', revision: '1' } })

      expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:cwl_client).at_least(:once).and_return(mock_cwl_client)
      expect_any_instance_of(EcsDeployCli::Runners::Base).to receive(:ecs_client).at_least(:once).and_return(mock_ecs_client)

      subject.update_task(tasks.values.first)
    end
  end
end
