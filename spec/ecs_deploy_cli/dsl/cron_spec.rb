require 'spec_helper'

describe EcsDeployCli::DSL::Cron do
  context 'defines cron data' do
    subject { described_class.new('test', { aws_profile_id: '123123', aws_region: 'eu-central-1' }) }

    let(:container) do
      EcsDeployCli::DSL::Container.new('web', { aws_profile_id: '123123', aws_region: 'eu-central-1' }).as_definition
    end

    let(:task) do
      task = EcsDeployCli::DSL::Task.new('some', { aws_profile_id: '123123', aws_region: 'eu-central-1' })
      task.containers :web

      task.as_definition({ web: container })
    end

    it '#task' do
      subject.task :some do
        container :web do
          command 'rails', 'run:task'
          memory limit: 2048, reservation: 1024
        end
      end
      subject.subnets 'subnet-1298ca5f'
      subject.security_groups 'sg-1298ca5f'
      subject.launch_type 'FARGATE'
      subject.task_role 'ecsEventsRole'
      subject.run_every '2 hours'
      subject.assign_public_ip true

      expect(subject.as_definition({ 'some' => task })).to eq(
        {
          task_name: 'some',
          input: {
            'containerOverrides' => [
              { command: ['rails', 'run:task'], memory: 2048, memory_reservation: 1024, name: 'web' }
            ],
            'taskRoleArn' => 'arn:aws:iam::123123:role/ecsEventsRole'
          },
          rule: {
            name: 'test',
            schedule_expression: 'rate(2 hours)'
          },
          ecs_parameters: {
            task_count: 1,
            launch_type: 'FARGATE',
            network_configuration: {
              awsvpc_configuration: {
                subnets: ['subnet-1298ca5f'],
                assign_public_ip: 'ENABLED',
                security_groups: ['sg-1298ca5f']
              }
            },
            platform_version: 'LATEST'
          }
        }
      )
    end
  end
end
