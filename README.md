# SorbetModelAttributes

Typed JSON/JSONB attributes for ActiveRecord models using [Sorbet](https://sorbet.org/)'s `T::Struct`. Serialize and deserialize structured data with full type safety, validations, and defaults -- no more raw hash access.

## Installation

Add to your Gemfile:

```ruby
gem "sorbet-model-attributes"
```

## Usage

### Define a struct

```ruby
class UserSettings < T::Struct
  prop :theme, String, default: "light"
  prop :font_size, Integer, default: 14
  prop :notifications, T::Boolean, default: true
end
```

### Declare the attribute on your model

```ruby
class User < ActiveRecord::Base
  sorbet_attributes :settings, UserSettings
end
```

The underlying column (`:settings`) should be a `json` or `jsonb` column in your database.

### Read and write

```ruby
user = User.create!(settings: { theme: "dark", font_size: 16, notifications: false })

user.settings          # => #<UserSettings theme="dark" font_size=16 notifications=false>
user.settings.theme    # => "dark"

# Assign a struct
user.settings = UserSettings.new(theme: "blue", font_size: 20, notifications: true)

# Assign a hash (validated and coerced automatically)
user.settings = { theme: "blue", font_size: 20, notifications: true }

# Assign nil
user.settings = nil
```

### In-place mutation

Modify struct properties directly -- changes are persisted on `save`:

```ruby
user.settings.theme = "dark"
user.save!
```

### Defaults

Missing keys fall back to the defaults defined on the struct:

```ruby
user = User.create!(settings: {})
user.settings.theme          # => "light"
user.settings.font_size      # => 14
user.settings.notifications  # => true
```

### Multiple attributes

A single model can have any number of typed attributes:

```ruby
class User < ActiveRecord::Base
  sorbet_attributes :settings, UserSettings
  sorbet_attributes :preferences, UserPreferences
end
```

## Sorbet & Tapioca support

The gem ships with a custom [Tapioca](https://github.com/Shopify/tapioca) DSL compiler that generates RBI files for every `sorbet_attributes` declaration. Run:

```sh
bundle exec tapioca dsl
```

This generates typed getter/setter signatures so Sorbet understands the methods:

```rbi
# sorbet/rbi/dsl/user.rbi
# typed: true

class User
  sig { returns(T.nilable(::UserSettings)) }
  def settings; end

  sig { params(value: T.nilable(T.any(::UserSettings, T::Hash[T.untyped, T.untyped]))).void }
  def settings=(value); end
end
```

## Rails integration

In a Rails app, `SorbetModelAttributes::ModelConcern` is automatically included into `ActiveRecord::Base` via a Railtie. No manual setup required.

Outside of Rails, include the concern manually:

```ruby
ActiveRecord::Base.include(SorbetModelAttributes::ModelConcern)
```

## Requirements

- Ruby >= 3.2
- Rails >= 7.0
- [sorbet-runtime](https://github.com/sorbet/sorbet) >= 0.6
- [sorbet-schema](https://github.com/maxveldink/sorbet-schema) >= 0.9

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/akodkod/sorbet-model-attributes. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/akodkod/sorbet-model-attributes/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
