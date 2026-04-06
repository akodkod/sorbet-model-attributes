# typed: false
# frozen_string_literal: true

module SorbetModelAttributes
  module ModelConcern
    extend ActiveSupport::Concern

    included do
      class_attribute :_sorbet_attribute_definitions, instance_writer: false, default: {}

      before_save :_serialize_sorbet_attributes
    end

    class_methods do # rubocop:disable Metrics/BlockLength
      def sorbet_attributes(column_name, struct_class, optional: false)
        column_name = column_name.to_sym
        serializer = Typed::HashSerializer.new(schema: struct_class.schema)

        self._sorbet_attribute_definitions = _sorbet_attribute_definitions.merge(
          column_name => { struct_class: struct_class, serializer: serializer, optional: optional },
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
            raise SorbetModelAttributes::DeserializationError,
                  _build_detailed_deserialization_error(column_name, serializer.schema, hash, result.error)
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
        raise SorbetModelAttributes::SerializationError,
              "Failed to serialize #{column_name}: #{result.error}"
      end

      write_attribute(column_name, result.payload)
      instance_variable_set(ivar, struct)
    end

    private def _write_sorbet_hash(column_name, ivar, serializer, hash)
      deserialize_result = serializer.deserialize(hash)

      unless deserialize_result.success?
        raise SorbetModelAttributes::DeserializationError,
              _build_detailed_deserialization_error(column_name, serializer.schema, hash, deserialize_result.error)
      end

      serialize_result = serializer.serialize(deserialize_result.payload)

      unless serialize_result.success?
        raise SorbetModelAttributes::SerializationError,
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
          raise SorbetModelAttributes::SerializationError,
                "Failed to serialize #{column_name}: #{result.error}"
        end

        write_attribute(column_name, result.payload)
      end
    end

    private def _build_detailed_deserialization_error(column_name, schema, hash, original_error)
      field_errors = _collect_nested_field_errors(schema, hash)

      if field_errors.any?
        "Failed to deserialize '#{column_name}':\n#{field_errors.map { |e| "  - #{e}" }.join("\n")}"
      else
        "Failed to deserialize '#{column_name}': #{original_error}"
      end
    end

    private def _collect_nested_field_errors(schema, hash, prefix = nil)
      hash = hash.transform_keys(&:to_sym)
      errors = []

      schema.fields.each do |field|
        value = hash[field.name]
        field_path = [prefix, field.name].compact.join(".")

        next if value.nil? && !field.default.nil?
        next if value.nil? && field.optional?

        if value.nil? && field.required?
          errors << "#{field_path}: is required but missing"
          next
        end

        next if field.works_with?(value)

        nested_errors = _try_nested_errors(field, value, field_path)
        if nested_errors.any?
          errors.concat(nested_errors)
        else
          coercion_result = Typed::Coercion.coerce(type: field.type, value: value)
          if coercion_result.failure?
            errors << "#{field_path}: #{coercion_result.error.message} (expected #{field.type}, got #{value.class}: #{value.inspect})"
          end
        end
      end

      errors
    end

    private def _try_nested_errors(field, value, field_path)
      type = field.type

      if _struct_type?(type) && value.is_a?(Hash)
        struct_class = type.respond_to?(:raw_type) ? type.raw_type : nil
        return [] unless struct_class.respond_to?(:schema)

        _collect_nested_field_errors(struct_class.schema, value, field_path)
      elsif type.is_a?(T::Types::TypedArray) && value.is_a?(Array)
        element_type = type.type
        return [] unless _struct_type?(element_type)

        struct_class = element_type.respond_to?(:raw_type) ? element_type.raw_type : nil
        return [] unless struct_class.respond_to?(:schema)

        value.each_with_index.flat_map do |element, index|
          next [] unless element.is_a?(Hash)

          _collect_nested_field_errors(struct_class.schema, element, "#{field_path}[#{index}]")
        end
      else
        []
      end
    end

    private def _struct_type?(type)
      return false unless type.respond_to?(:raw_type)

      type.raw_type < T::Struct
    rescue TypeError
      false
    end
  end
end
