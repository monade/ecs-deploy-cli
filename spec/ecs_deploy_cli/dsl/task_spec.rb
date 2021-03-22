require 'spec_helper'

describe EcsDeployCli::DSL::Task do
  context 'defines task data' do
    subject { described_class.new('test', { aws_profile_id: '123123', aws_region: 'eu-central-1' }) }

    it 'has family name equals test' do
      expect(subject.as_definition({})[:family]).to eq('test')
    end

    it '#tag adds a tag' do
      subject.tag 'product', 'yourproject'
      subject.tag 'product2', 'yourproject2'
      expect(subject.as_definition({})[:tags]).to eq(
        [
          { key: 'product', value: 'yourproject' },
          { key: 'product2', value: 'yourproject2' }
        ]
      )
    end

    it '#execution_role' do
      subject.execution_role 'someRole'
      expect(subject.as_definition({})[:execution_role_arn]).to eq(
        'arn:aws:iam::123123:role/someRole'
      )
    end

    it 'fallbacks not handled methods to an option in the container definition' do
      subject.cpu 256
      expect(subject.as_definition({})[:cpu]).to eq('256')
    end
  end
end
