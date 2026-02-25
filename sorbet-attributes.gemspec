# frozen_string_literal: true

require_relative "lib/sorbet-attributes/version"

Gem::Specification.new do |spec|
  spec.name = "sorbet-attributes"
  spec.version = SorbetAttributes::VERSION
  spec.authors = ["Andrew Kodkod"]
  spec.email = ["andrew@kodkod.me"]

  spec.summary = "Typed JSON attributes for ActiveRecord models using Sorbet's T::Struct"
  spec.description = "Add typed JSON attributes to your ActiveRecord models using Sorbet's T::Struct"
  spec.homepage = "https://github.com/akodkod/sorbet-attributes"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = "https://github.com/akodkod/sorbet-attributes"
  spec.metadata["changelog_uri"] = "https://github.com/akodkod/sorbet-attributes/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "Gemfile", ".gitignore", ".rspec", "spec/", ".github/", ".rubocop.yml")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "sorbet-runtime", ">= 0.6"
  spec.add_dependency "sorbet-schema", ">= 0.9"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
