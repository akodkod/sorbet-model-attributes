# frozen_string_literal: true

class UserSettings < T::Struct
  prop :theme, String, default: "light"
  prop :font_size, Integer, default: 14
  prop :notifications, T::Boolean, default: true
end

class UserPreferences < T::Struct
  prop :language, String, default: "en"
  prop :timezone, String, default: "UTC"
end
