# frozen_string_literal: true

require 'spec_helper'

describe EcsDeployCli::DSL::Cluster do
  context 'defines cluster data' do
    subject { described_class.new('mydata-cluster', { aws_profile_id: '123123', aws_region: 'eu-central-1' }) }

    it '#vpc' do
      subject.instances_count 1
      subject.instance_type 't2.small'
      subject.keypair_name 'test'

      subject.vpc do
        cidr '11.0.0.0/16'
        subnet1 '11.0.0.0/24'
        subnet2 '11.0.1.0/24'
        subnet3 '11.0.2.0/24'
        subnet_ids 'subnet-123', 'subnet-321', 'subnet-333'

        availability_zones 'eu-central-1a', 'eu-central-1b', 'eu-central-1c'
      end

      expect(subject.as_definition).to eq(
        {
          device_name: '/dev/xvda',
          ebs_volume_size: 22,
          ebs_volume_type: 'gp2',
          instances_count: 1,
          instance_type: 't2.small',
          keypair_name: 'test',
          name: 'mydata-cluster',
          root_device_name: '/dev/xvdcz',
          root_ebs_volume_size: 30,
          vpc: {
            availability_zones: 'eu-central-1a,eu-central-1b,eu-central-1c',
            cidr: '11.0.0.0/16',
            id: nil,
            subnet1: '11.0.0.0/24',
            subnet2: '11.0.1.0/24',
            subnet3: '11.0.2.0/24',
            subnet_ids: 'subnet-123,subnet-321,subnet-333'
          }
        }
      )
    end
  end
end
