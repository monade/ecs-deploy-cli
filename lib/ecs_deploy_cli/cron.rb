# frozen_string_literal: true

module EcsDeployCli
  class Cron
    include AutoOptions

    def initialize(name, config); end

    def task(name)
      _options[:task] = name.to_s
    end

    def as_definition(containers)
      raise NotImplementedError
    end
  end
end
