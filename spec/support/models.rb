# frozen_string_literal: true

class User < ActiveRecord::Base
  sorbet_attributes :settings, UserSettings, optional: true
  sorbet_attributes :preferences, UserPreferences
end
