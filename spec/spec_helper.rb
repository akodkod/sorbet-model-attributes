# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "sorbet-attributes"
require "active_record"

require_relative "support/database"
require_relative "support/structs"
require_relative "support/models"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
