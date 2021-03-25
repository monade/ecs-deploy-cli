# frozen_string_literal: true

module EcsDeployCli
  module DSL
    module AutoOptions
      extend ActiveSupport::Concern

      module ClassMethods
        def allowed_options(*value)
          @allowed_options = value
        end

        def _allowed_options
          @allowed_options ||= []
        end
      end

      def method_missing(name, *args, &block)
        if args.count == 1 && !block
          unless self.class._allowed_options.include?(name)
            EcsDeployCli.logger.info("Used unhandled option #{name.to_sym} = #{args.first} in #{self.class.name}")
          end
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
