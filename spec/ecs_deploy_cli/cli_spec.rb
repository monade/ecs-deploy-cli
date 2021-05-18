# frozen_string_literal: true

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

    it 'runs diff' do
      expect(runner).to receive(:diff)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end

      described_class.start(['diff', '--file', 'spec/support/ECSFile'])
    end

    it 'runs validate' do
      expect(runner).to receive(:validate!)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end
      expect { described_class.start(['validate', '--file', 'spec/support/ECSFile']) }.to output(/Your ECSFile looks fine! 🎉/).to_stdout
    end

    it 'runs run-task' do
      expect(runner).to receive(:run_task!)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end

      described_class.start(['run-task', 'yourproject', '--subnets', 'subnet-123123', '--file', 'spec/support/ECSFile'])
    end

    it 'runs setup' do
      expect(runner).to receive(:setup!)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end
      expect { described_class.start(['setup', '--file', 'spec/support/ECSFile']) }.to output(/[WARNING]/).to_stdout
    end

    it 'runs deploy' do
      expect(runner).to receive(:update_crons!)
      expect(runner).to receive(:update_services!).with(timeout: 500)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end
      expect { described_class.start(['deploy', '--file', 'spec/support/ECSFile']) }.to output(/[WARNING]/).to_stdout
    end

    it 'runs deploy-services' do
      expect(runner).to receive(:update_services!)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).and_return(runner)
      end
      expect { described_class.start(['deploy-services', '--file', 'spec/support/ECSFile']) }.to output(/[WARNING]/).to_stdout
    end

    it 'runs ssh' do
      expect(runner).to receive(:ssh)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).and_return(runner)
      end

      described_class.start(['ssh', '--file', 'spec/support/ECSFile'])
    end

    it 'runs deploy-scheduled-tasks' do
      expect(runner).to receive(:update_crons!)
      described_class.no_commands do
        expect_any_instance_of(described_class).to receive(:runner).at_least(:once).and_return(runner)
      end

      described_class.start(['deploy-scheduled-tasks', '--file', 'spec/support/ECSFile'])
    end
  end
end
