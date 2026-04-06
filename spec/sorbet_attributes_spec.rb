# frozen_string_literal: true

RSpec.describe SorbetModelAttributes::ModelConcern do
  describe "getter" do
    it "deserializes JSONB to struct" do
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: false, role: :admin })

      expect(user.settings).to be_a(UserSettings)
      expect(user.settings.theme).to eq("dark")
      expect(user.settings.font_size).to eq(16)
      expect(user.settings.notifications).to be(false)
      expect(user.settings.role).to eq(:admin)
    end

    it "returns nil for nil column" do
      user = User.create!(settings: nil)

      expect(user.settings).to be_nil
    end

    it "memoizes the struct instance" do
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: true })

      first_access = user.settings
      second_access = user.settings

      expect(first_access.object_id).to eq(second_access.object_id)
    end

    it "deserializes from a freshly loaded record" do
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: true, role: :admin })
      loaded = User.find(user.id)

      expect(loaded.settings).to be_a(UserSettings)
      expect(loaded.settings.theme).to eq("dark")
      expect(loaded.settings.role).to eq(:admin)
    end
  end

  describe "setter" do
    it "assigns a struct instance" do
      user = User.new
      user.settings = UserSettings.new(theme: "dark", font_size: 18, notifications: false)
      user.save!

      loaded = User.find(user.id)
      expect(loaded.settings.theme).to eq("dark")
      expect(loaded.settings.font_size).to eq(18)
    end

    it "assigns a Hash" do
      user = User.new
      user.settings = { theme: "blue", font_size: 20, notifications: true }
      user.save!

      loaded = User.find(user.id)
      expect(loaded.settings.theme).to eq("blue")
      expect(loaded.settings.font_size).to eq(20)
    end

    it "assigns nil" do
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: true })
      user.settings = nil
      user.save!

      loaded = User.find(user.id)
      expect(loaded.settings).to be_nil
    end

    it "rejects invalid types" do
      user = User.new

      expect { user.settings = "invalid" }.to raise_error(ArgumentError, /must be a UserSettings, Hash, or nil/)
    end

    it "provides detailed field-level errors for invalid hash values" do
      user = User.new

      expect { user.settings = { font_size: "not_a_number" } }.to raise_error(
        SorbetModelAttributes::DeserializationError,
      ) do |error|
        expect(error.message).to include("Failed to deserialize 'settings':")
        expect(error.message).to include("- font_size:")
        expect(error.message).to include("got String")
      end
    end
  end

  describe "in-place mutation" do
    it "persists changes to struct properties on save" do
      user = User.create!(settings: { theme: "light", font_size: 14, notifications: true })

      user.settings.theme = "dark"
      user.save!

      loaded = User.find(user.id)
      expect(loaded.settings.theme).to eq("dark")
    end
  end

  describe "reload" do
    it "clears cached struct and re-reads from database" do
      user = User.create!(settings: { theme: "light", font_size: 14, notifications: true })

      user.settings.theme = "dark"

      user.reload

      expect(user.settings.theme).to eq("light")
    end
  end

  describe "multiple attributes" do
    it "supports independent attributes on the same model" do
      user = User.create!(
        settings: { theme: "dark", font_size: 16, notifications: false },
        preferences: { language: "fr", timezone: "Europe/Paris" },
      )

      expect(user.settings).to be_a(UserSettings)
      expect(user.settings.theme).to eq("dark")

      expect(user.preferences).to be_a(UserPreferences)
      expect(user.preferences.language).to eq("fr")
      expect(user.preferences.timezone).to eq("Europe/Paris")
    end
  end

  describe "nested structs" do
    let(:nested_hash) do
      {
        microsoft_organization: {
          id: "abc-123",
          display_name: "Test Org",
          verified_domains: [
            { name: "test.com", is_default: true },
            { name: "test2.com", is_default: false },
          ],
          directory_size_quota: { used: 655, total: 300_000 },
        },
      }
    end

    let(:string_key_hash) do
      {
        "microsoft_organization" => {
          "id" => "abc-123",
          "display_name" => "Test Org",
          "verified_domains" => [
            { "name" => "test.com", "is_default" => true },
            { "name" => "test2.com", "is_default" => false },
          ],
          "directory_size_quota" => { "used" => 655, "total" => 300_000 },
        },
      }
    end

    it "deserializes nested struct from JSONB" do
      user = User.create!(data: nested_hash)

      expect(user.data).to be_a(OAuthData)
      expect(user.data.microsoft_organization).to be_a(OrganizationInfo)
      expect(user.data.microsoft_organization.display_name).to eq("Test Org")
      expect(user.data.microsoft_organization.verified_domains).to all(be_a(VerifiedDomain))
      expect(user.data.microsoft_organization.verified_domains.first.name).to eq("test.com")
      expect(user.data.microsoft_organization.directory_size_quota).to be_a(DirectorySizeQuota)
      expect(user.data.microsoft_organization.directory_size_quota.used).to eq(655)
    end

    it "deserializes nested struct from a freshly loaded record" do
      user = User.create!(data: nested_hash)
      loaded = User.find(user.id)

      expect(loaded.data.microsoft_organization.display_name).to eq("Test Org")
      expect(loaded.data.microsoft_organization.verified_domains.length).to eq(2)
      expect(loaded.data.microsoft_organization.verified_domains.last.name).to eq("test2.com")
      expect(loaded.data.microsoft_organization.directory_size_quota.total).to eq(300_000)
    end

    it "assigns nested hash with string keys" do
      user = User.new
      user.data = string_key_hash
      user.save!

      loaded = User.find(user.id)
      expect(loaded.data.microsoft_organization.display_name).to eq("Test Org")
      expect(loaded.data.microsoft_organization.verified_domains.first.is_default).to be(true)
    end

    it "assigns nested hash with symbol keys" do
      user = User.new
      user.data = nested_hash
      user.save!

      loaded = User.find(user.id)
      expect(loaded.data.microsoft_organization.id).to eq("abc-123")
    end

    it "persists changes to nested struct properties" do
      user = User.create!(data: nested_hash)

      user.data.microsoft_organization.display_name = "Updated Org"
      user.save!

      loaded = User.find(user.id)
      expect(loaded.data.microsoft_organization.display_name).to eq("Updated Org")
    end

    it "coerces string values to correct types in nested structs" do
      hash_with_string_values = {
        "microsoft_organization" => {
          "id" => "abc-123",
          "display_name" => "Test Org",
          "verified_domains" => [
            { "name" => "test.com", "is_default" => "true" },
            { "name" => "test2.com", "is_default" => "false" },
          ],
          "directory_size_quota" => { "used" => "655", "total" => "300000" },
        },
      }

      user = User.create!(data: hash_with_string_values)
      loaded = User.find(user.id)

      expect(loaded.data.microsoft_organization.verified_domains.first.is_default).to be(true)
      expect(loaded.data.microsoft_organization.verified_domains.last.is_default).to be(false)
      expect(loaded.data.microsoft_organization.directory_size_quota.used).to eq(655)
    end

    it "provides detailed nested field errors on coercion failure" do
      bad_hash = {
        "microsoft_organization" => {
          "id" => "abc-123",
          "display_name" => "Test Org",
          "verified_domains" => [
            { "name" => "test.com", "is_default" => "" },
          ],
          "directory_size_quota" => { "used" => "655", "total" => "300000" },
        },
      }

      expect { User.create!(data: bad_hash) }.to raise_error(
        SorbetModelAttributes::DeserializationError,
      ) do |error|
        expect(error.message).to include("verified_domains[0].is_default")
      end
    end
  end

  describe "defaults" do
    it "applies struct defaults for missing keys" do
      user = User.create!(settings: { theme: "dark" })

      expect(user.settings.font_size).to eq(14)
      expect(user.settings.notifications).to be(true)
    end

    it "applies struct defaults for empty hash" do
      user = User.create!(settings: {})

      expect(user.settings.theme).to eq("light")
      expect(user.settings.font_size).to eq(14)
      expect(user.settings.notifications).to be(true)
    end
  end
end
