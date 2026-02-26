# typed: strict
# frozen_string_literal: true

require "active_record"
require "sorbet-runtime"
require "sorbet-schema"

require "sorbet-model-attributes/version"
require "sorbet-model-attributes/model_concern"
require "sorbet-model-attributes/railtie" if defined?(Rails)

module SorbetModelAttributes
  class Error < StandardError; end
  class DeserializationError < Error; end
  class SerializationError < Error; end
end
