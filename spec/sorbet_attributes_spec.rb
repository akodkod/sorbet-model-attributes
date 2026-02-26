# frozen_string_literal: true

RSpec.describe SorbetModelAttributes::ModelConcern do
  describe "getter" do
    it "deserializes JSONB to struct" do
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: false })

      expect(user.settings).to be_a(UserSettings)
      expect(user.settings.theme).to eq("dark")
      expect(user.settings.font_size).to eq(16)
      expect(user.settings.notifications).to be(false)
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
      user = User.create!(settings: { theme: "dark", font_size: 16, notifications: true })
      loaded = User.find(user.id)

      expect(loaded.settings).to be_a(UserSettings)
      expect(loaded.settings.theme).to eq("dark")
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
