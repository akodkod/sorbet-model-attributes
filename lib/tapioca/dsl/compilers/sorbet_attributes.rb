# typed: strict
# frozen_string_literal: true

return unless defined?(SorbetAttributes::ModelConcern)

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
              struct_type = T.must(struct_class.name)

              create_getter(klass, column_name.to_s, struct_type)
              create_setter(klass, column_name.to_s, struct_type)
            end
          end
        end

        sig { params(klass: RBI::Scope, name: String, struct_type: String).void }
        private def create_getter(klass, name, struct_type)
          klass.create_method(
            name,
            return_type: "T.nilable(::#{struct_type})",
          )
        end

        sig { params(klass: RBI::Scope, name: String, struct_type: String).void }
        private def create_setter(klass, name, struct_type)
          klass.create_method(
            "#{name}=",
            parameters: [
              create_param("value", type: "T.nilable(T.any(::#{struct_type}, T::Hash[T.untyped, T.untyped]))"),
            ],
            return_type: "void",
          )
        end
      end
    end
  end
end
