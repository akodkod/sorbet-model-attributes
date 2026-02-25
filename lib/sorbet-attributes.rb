# typed: strict
# frozen_string_literal: true

require "active_record"
require "sorbet-runtime"
require "sorbet-schema"

require "sorbet-attributes/version"
require "sorbet-attributes/model_concern"
require "sorbet-attributes/railtie" if defined?(Rails)

module SorbetAttributes
  class Error < StandardError; end
  class DeserializationError < Error; end
  class SerializationError < Error; end
end
