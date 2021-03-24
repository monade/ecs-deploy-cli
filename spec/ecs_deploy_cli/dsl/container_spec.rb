require 'spec_helper'

describe EcsDeployCli::DSL::Container do
  context 'defines container data' do
    subject { described_class.new('test', { aws_profile_id: '123123', aws_region: 'eu-central-1' }) }

    it 'has the correct name' do
      expect(subject.as_definition[:name]).to eq('test')
    end

    it '#memory configures memory' do
      subject.memory limit: 1024, reservation: 900
      expect(subject.as_definition[:memory]).to eq(1024)
      expect(subject.as_definition[:memory_reservation]).to eq(900)
    end

    it '#env configures a single env' do
      subject.env key: 'SOME', value: 'env'
      subject.env key: 'SOME2', value: 'env2'
      expect(subject.as_definition[:environment]).to eq(
        [
          {
            'name' => 'SOME', 'value' => 'env'
          },
          {
            'name' => 'SOME2', 'value' => 'env2'
          }
        ]
      )
    end

    it '#cloudwatch_logs configures cloudwatch logs' do
      subject.cloudwatch_logs 'yourproject'
      expect(subject.as_definition[:log_configuration]).to eq(
        {
          log_driver: 'awslogs',
          options: { 'awslogs-group' => '/ecs/yourproject', 'awslogs-region' => 'eu-central-1', 'awslogs-stream-prefix' => 'ecs' }
        }
      )
    end

    it '#secret configures secrets' do
      subject.secret key: 'RAILS_MASTER_KEY', value: 'railsMasterKey'

      expect(subject.as_definition[:secrets]).to eq(
        [
          {
            name: 'RAILS_MASTER_KEY',
            value_from: 'arn:aws:ssm:eu-central-1:123123:parameter/railsMasterKey'
          }
        ]
      )
    end

    it '#merge: merges two containers' do
      other = described_class.new('base', { aws_profile_id: '123123', aws_region: 'eu-central-1' })
      other.expose host_port: 0, protocol: 'tcp', container_port: 3000

      subject.secret key: 'RAILS_MASTER_KEY', value: 'railsMasterKey'
      subject.merge(other)

      expect(subject.as_definition[:secrets]).to eq(
        [
          {
            name: 'RAILS_MASTER_KEY',
            value_from: 'arn:aws:ssm:eu-central-1:123123:parameter/railsMasterKey'
          }
        ]
      )

      expect(subject.as_definition[:port_mappings]).to eq(
        [
          { host_port: 0, protocol: 'tcp', container_port: 3000 }
        ]
      )
    end

    it '#expose: configures port mapping' do
      subject.expose host_port: 0, protocol: 'tcp', container_port: 3000
      expect(subject.as_definition[:port_mappings]).to eq(
        [
          { host_port: 0, protocol: 'tcp', container_port: 3000 }
        ]
      )
    end

    it '#load_envs loads env files' do
      subject.load_envs 'spec/support/env_file.yml'
      expect(subject.as_definition[:environment]).to eq(
        [
          {
            'name' => 'RAILS_ENV', 'value' => 'production'
          },
          {
            'name' => 'API_KEY', 'value' => '123123123'
          }
        ]
      )
    end

    it 'fallbacks not handled methods to an option in the container definition' do
      subject.image 'some_image:version'
      expect(subject.as_definition[:image]).to eq('some_image:version')
    end
  end
end
