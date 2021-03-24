module EcsDeployCli
  module DSL
    module AutoOptions
      def method_missing(name, *args, &block)
        if args.count == 1 && !block
          EcsDeployCli.logger.info("Auto-added option security_group #{name.to_sym} = #{args.first}")
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
end
