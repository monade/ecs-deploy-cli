require 'spec_helper'

describe EcsDeployCli::CLI do
  context 'defines task data' do
    let(:runner) { double }

    around(:each) do |example|
      ENV['AWS_PROFILE_ID'] = '123123123'
      ENV['AWS_REGION'] = 'us-east-1'
      example.run
      ENV['AWS_PROFILE_ID'] = nil
      ENV['AWS_REGION'] = nil
    end

    it 'runs help' do
      expect { described_class.start(['help']) }.to output(/rspec deploy-scheduled-tasks/).to_stdout
    end

    it 'runs version' do
      expect { described_class.start(['version']) }.to output(/Version #{EcsDeployCli::VERSION}/).to_stdout
    end

    it 'runs deploy-services' do
      expect(runner).to receive(:update_services!)
      expect_any_instance_of(described_class).to receive(:runner).and_return(runner)
      expect { described_class.start(['deploy-services', '--file', 'spec/support/ECSFile']) }.to output(/[WARNING]/).to_stdout
    end

    it 'runs ssh' do
      # described_class.start(['ssh', '--file', 'spec/support/ECSFile'])
      skip 'TODO: Implement feature'
    end

    it 'runs deploy-scheduled-tasks' do
      # described_class.start(['ssh', '--file', 'spec/support/ECSFile'])
      skip 'TODO: Implement feature'
    end
  end
end
