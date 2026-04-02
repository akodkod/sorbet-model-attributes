# typed: strict
# frozen_string_literal: true

return unless defined?(SorbetModelAttributes::ModelConcern)

module Tapioca
  module Dsl
    module Compilers
      # rubocop:disable Layout/LeadingCommentSpace
      #: [ConstantType = singleton(::ActiveRecord::Base)]
      # rubocop:enable Layout/LeadingCommentSpace
      class SorbetAttributes < Compiler
        extend T::Sig

        class << self
          extend T::Sig

          sig { override.returns(T::Enumerable[Module]) }
          def gather_constants
            descendants_of(::ActiveRecord::Base).select do |klass|
              klass.respond_to?(:_sorbet_attribute_definitions) &&
                klass._sorbet_attribute_definitions.any?
            end
          end
        end

        sig { override.void }
        def decorate
          definitions = constant._sorbet_attribute_definitions
          return if definitions.empty?

          root.create_path(constant) do |klass|
            definitions.each do |column_name, config|
              struct_class = config[:struct_class]
              struct_type = struct_class.name
              optional = config.fetch(:optional, false)

              create_getter(klass, column_name.to_s, struct_type, optional)
              create_setter(klass, column_name.to_s, struct_type, optional)
            end
          end
        end

        sig { params(klass: RBI::Scope, name: String, struct_type: String, optional: T::Boolean).void }
        private def create_getter(klass, name, struct_type, optional)
          return_type = if optional
                          "T.nilable(::#{struct_type})"
                        else
                          "::#{struct_type}"
                        end

          klass.create_method(
            name,
            return_type: return_type,
          )
        end

        sig { params(klass: RBI::Scope, name: String, struct_type: String, optional: T::Boolean).void }
        private def create_setter(klass, name, struct_type, optional)
          value_type = if optional
                         "T.nilable(T.any(::#{struct_type}, T::Hash[T.untyped, T.untyped]))"
                       else
                         "T.any(::#{struct_type}, T::Hash[T.untyped, T.untyped])"
                       end

          klass.create_method(
            "#{name}=",
            parameters: [
              create_param("value", type: value_type),
            ],
            return_type: "void",
          )
        end
      end
    end
  end
end
