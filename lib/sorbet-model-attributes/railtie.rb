# typed: false
# frozen_string_literal: true

module SorbetModelAttributes
  class Railtie < ::Rails::Railtie
    initializer "sorbet_attributes.include_model_concern" do
      ActiveSupport.on_load(:active_record) do
        include SorbetModelAttributes::ModelConcern
      end
    end
  end
end
