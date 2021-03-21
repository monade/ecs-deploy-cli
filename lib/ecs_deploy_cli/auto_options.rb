module EcsDeployCli
  module AutoOptions
    def method_missing(name, *args, &block)
      if args.count == 1 && !block
        _options[name.to_sym] = args.first
      else
        super
      end
    end

    def _options
      @_options ||= {}
    end
  end
end
