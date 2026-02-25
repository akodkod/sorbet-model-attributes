# typed: false
# frozen_string_literal: true

module SorbetAttributes
  module ModelConcern
    extend ActiveSupport::Concern

    included do
      class_attribute :_sorbet_attribute_definitions, instance_writer: false, default: {}

      before_save :_serialize_sorbet_attributes
    end

    class_methods do # rubocop:disable Metrics/BlockLength
      def sorbet_attributes(column_name, struct_class)
        column_name = column_name.to_sym
        serializer = Typed::HashSerializer.new(schema: struct_class.schema)

        self._sorbet_attribute_definitions = _sorbet_attribute_definitions.merge(
          column_name => { struct_class: struct_class, serializer: serializer },
        )

        _define_sorbet_getter(column_name, serializer)
        _define_sorbet_setter(column_name, struct_class, serializer)
      end

      private def _define_sorbet_getter(column_name, serializer)
        ivar = :"@_sorbet_#{column_name}"

        define_method(column_name) do
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          raw = read_attribute(column_name)
          return nil if raw.nil?

          hash = raw.is_a?(String) ? JSON.parse(raw) : raw
          result = serializer.deserialize(hash)

          unless result.success?
            raise SorbetAttributes::DeserializationError,
                  "Failed to deserialize #{column_name}: #{result.error}"
          end

          instance_variable_set(ivar, result.payload)
        end
      end

      private def _define_sorbet_setter(column_name, struct_class, serializer)
        ivar = :"@_sorbet_#{column_name}"

        define_method(:"#{column_name}=") do |value|
          case value
          when struct_class
            _write_sorbet_struct(column_name, ivar, serializer, value)
          when Hash
            _write_sorbet_hash(column_name, ivar, serializer, value)
          when nil
            write_attribute(column_name, nil)
            remove_instance_variable(ivar) if instance_variable_defined?(ivar)
          else
            raise ArgumentError,
                  "#{column_name} must be a #{struct_class.name}, Hash, or nil, got #{value.class.name}"
          end
        end
      end
    end

    def reload(...)
      _sorbet_attribute_definitions.each_key do |column_name|
        ivar = :"@_sorbet_#{column_name}"
        remove_instance_variable(ivar) if instance_variable_defined?(ivar)
      end

      super
    end

    private def _write_sorbet_struct(column_name, ivar, serializer, struct)
      result = serializer.serialize(struct)

      unless result.success?
        raise SorbetAttributes::SerializationError,
              "Failed to serialize #{column_name}: #{result.error}"
      end

      write_attribute(column_name, result.payload)
      instance_variable_set(ivar, struct)
    end

    private def _write_sorbet_hash(column_name, ivar, serializer, hash)
      deserialize_result = serializer.deserialize(hash)

      unless deserialize_result.success?
        raise SorbetAttributes::DeserializationError,
              "Failed to deserialize #{column_name}: #{deserialize_result.error}"
      end

      serialize_result = serializer.serialize(deserialize_result.payload)

      unless serialize_result.success?
        raise SorbetAttributes::SerializationError,
              "Failed to serialize #{column_name}: #{serialize_result.error}"
      end

      write_attribute(column_name, serialize_result.payload)
      instance_variable_set(ivar, deserialize_result.payload)
    end

    private def _serialize_sorbet_attributes
      _sorbet_attribute_definitions.each do |column_name, config|
        ivar = :"@_sorbet_#{column_name}"
        next unless instance_variable_defined?(ivar)

        struct = instance_variable_get(ivar)
        next if struct.nil?

        result = config[:serializer].serialize(struct)

        unless result.success?
          raise SorbetAttributes::SerializationError,
                "Failed to serialize #{column_name}: #{result.error}"
        end

        write_attribute(column_name, result.payload)
      end
    end
  end
end
