require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Auth
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Tenants live at <subdomain>.<root_domain> or on their own custom domain.
    config.x.root_domain = ENV.fetch("APP_ROOT_DOMAIN", "localhost")

    # Cloudflare for SaaS verifies tenant custom domains and issues their certificates.
    # Tenants CNAME their domain to cname_target, which points at the zone's fallback origin.
    config.x.cloudflare.api_token = ENV["CLOUDFLARE_API_TOKEN"]
    config.x.cloudflare.zone_id = ENV["CLOUDFLARE_ZONE_ID"]
    config.x.cloudflare.cname_target = ENV.fetch("CLOUDFLARE_CNAME_TARGET") { "tenants.#{config.x.root_domain}" }
  end
end
