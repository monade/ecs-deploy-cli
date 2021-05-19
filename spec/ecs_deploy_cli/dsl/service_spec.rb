# frozen_string_literal: true

require 'spec_helper'

describe EcsDeployCli::DSL::Service do
  context 'defines service data' do
    subject { described_class.new('test', { aws_profile_id: '123123', aws_region: 'eu-central-1' }) }

    it 'has the correct name' do
      expect(subject.as_definition({})[:service]).to eq('test')
    end

    it '#load_balancer' do
      subject.load_balancer :'yourproject-load-balancer' do
        target_group_arn 'loader-target-group/123abc'
        container_name :web
        container_port 80
      end

      expect(subject.as_definition({})[:load_balancers]).to eq(
        [
          {
            container_name: :web,
            container_port: 80,
            target_group_arn: 'arn:aws:elasticloadbalancing:eu-central-1:123123:targetgroup/loader-target-group/123abc'
          }
        ]
      )
    end
  end
end
