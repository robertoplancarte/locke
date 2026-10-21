Rails.application.config.middleware.use OmniAuth::Builder do
  provider :developer unless Rails.env.production? # You should replace it with your provider

  # Providers tenants register in their settings, configured per request from the
  # tenant's IdentityProvider. Each is served at /auth/<protocol>/<id>.
  { oidc: :openid_connect, saml: :saml }.each do |protocol, strategy|
    provider strategy,
      name: protocol,
      request_path: ->(env) { IdentityProvider::StrategySetup.on_path?(env, protocol:) },
      callback_path: ->(env) { IdentityProvider::StrategySetup.on_path?(env, protocol:, callback: true) },
      setup: ->(env) { IdentityProvider::StrategySetup.call(env) }
  end
end
