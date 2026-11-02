source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing framework [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"

  # Test data factories [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # MCP server for AI coding agents + installer for skills shipped by companion gems [https://github.com/rails-hyperdrive/rails-hyperdrive]
  gem "rails-hyperdrive"

  # Layered Rails architecture skills, installed via `bin/rails hyperdrive:init` [https://github.com/palkan/layered-rails-skills]
  gem "layered-rails-skills"

  # RSpec-writing skill for AI agents, installed via hyperdrive [https://github.com/rails-hyperdrive/rails-hyperdrive-martian-spec]
  gem "rails-hyperdrive-martian-spec"

  # Catch sent emails and browse them at /letter_opener [https://github.com/fgrehm/letter_opener_web]
  gem "letter_opener_web"
end

group :test do
  # Browser system specs driven by Playwright [https://github.com/YusukeIwaki/capybara-playwright-driver]
  gem "capybara"
  gem "capybara-playwright-driver"

  # Test suite profiling [https://test-prof.evilmartians.io/]
  gem "test-prof"

  # Stub HTTP requests to external APIs [https://github.com/bblimke/webmock]
  gem "webmock"
end
plugin "bundler-hyperdrive"

gem "acts_as_tenant", "~> 2.2"

gem "authentication-zero", "~> 4.0"
# Use Pwned to check if a password has been found in any of the huge data breaches [https://github.com/philnash/pwned]
gem "pwned"
# Use OmniAuth to support multi-provider authentication [https://github.com/omniauth/omniauth]
gem "omniauth"
# Provides a mitigation against CVE-2015-9284 [https://github.com/cookpad/omniauth-rails_csrf_protection]
gem "omniauth-rails_csrf_protection"
# Use rotp for generating and validating one time passwords [https://github.com/mdp/rotp]
gem "rotp"
# Use rqrcode for creating and rendering QR codes into various formats [https://github.com/whomwah/rqrcode]
gem "rqrcode"
# Use webauthn for making rails become a conformant web authn relying party [https://github.com/cedarcode/webauthn-ruby]
gem "webauthn"

gem "omniauth_openid_connect", "~> 0.8.0"
gem "omniauth-saml", "~> 2.2"

# Locke as an OAuth 2.0 / OpenID Connect provider for apps
gem "doorkeeper", "~> 5.8"
gem "doorkeeper-openid_connect", "~> 1.8"
