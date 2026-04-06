# frozen_string_literal: true

class UserSettings < T::Struct
  prop :theme, String, default: "light"
  prop :font_size, Integer, default: 14
  prop :notifications, T::Boolean, default: true
  prop :role, Symbol, default: :user
end

class UserPreferences < T::Struct
  prop :language, String, default: "en"
  prop :timezone, String, default: "UTC"
end

class VerifiedDomain < T::Struct
  prop :name, String
  prop :is_default, T::Boolean
end

class DirectorySizeQuota < T::Struct
  prop :used, Integer
  prop :total, Integer
end

class OrganizationInfo < T::Struct
  prop :id, String
  prop :display_name, String
  prop :verified_domains, T::Array[VerifiedDomain]
  prop :directory_size_quota, DirectorySizeQuota
end

class OAuthData < T::Struct
  prop :microsoft_organization, OrganizationInfo
end
