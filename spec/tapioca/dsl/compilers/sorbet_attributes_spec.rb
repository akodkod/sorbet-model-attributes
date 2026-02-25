# frozen_string_literal: true

require "spec_helper"
require "tapioca/dsl"
require "tapioca/dsl/compilers/sorbet_attributes"

RSpec.describe Tapioca::Dsl::Compilers::SorbetAttributes do
  def rbi_for(constant)
    file = RBI::File.new(strictness: "true")
    pipeline = Tapioca::Dsl::Pipeline.new(
      requested_constants: [constant],
      requested_compilers: [described_class],
    )

    compiler = described_class.new(pipeline, file.root, constant)
    compiler.decorate

    file.root.string
  end

  describe ".gather_constants" do
    it "includes models with sorbet_attributes" do
      expect(described_class.processable_constants).to include(User)
    end

    it "excludes ActiveRecord::Base itself" do
      expect(described_class.processable_constants).not_to include(ActiveRecord::Base)
    end
  end

  describe "#decorate" do
    it "generates correct getter and setter signatures" do
      output = rbi_for(User)

      expect(output).to include("def settings; end")
      expect(output).to include("def preferences; end")
      expect(output).to include("def settings=(value); end")
      expect(output).to include("def preferences=(value); end")
    end

    it "generates nilable return type for getter" do
      output = rbi_for(User)

      expect(output).to include("returns(T.nilable(::UserSettings))")
      expect(output).to include("returns(T.nilable(::UserPreferences))")
    end

    it "generates union type for setter parameter" do
      output = rbi_for(User)

      expect(output).to include(
        "params(value: T.nilable(T.any(::UserSettings, T::Hash[T.untyped, T.untyped])))",
      )
      expect(output).to include(
        "params(value: T.nilable(T.any(::UserPreferences, T::Hash[T.untyped, T.untyped])))",
      )
    end

    it "generates void return type for setter" do
      output = rbi_for(User)

      setter_lines = output.lines.select { |line| line.include?(".void") }
      expect(setter_lines.length).to eq(2)
    end
  end
end
