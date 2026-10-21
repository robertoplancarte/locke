# OmniAuth setup phase for tenant-registered providers. Every tenant's providers
# share one strategy per protocol, served at /auth/<protocol>/<id>; this loads the
# provider for the request's tenant and configures the strategy with it.
class IdentityProvider::StrategySetup
  PATH = %r{\A/auth/(?<protocol>oidc|saml)/(?<id>\d+)(?<callback>/callback)?/?\z}

  # Whether the request is for a protocol's request (or callback) path, whichever provider it's for
  def self.on_path?(env, protocol:, callback: false)
    match = PATH.match(env["PATH_INFO"].to_s)
    match.present? && match[:protocol] == protocol.to_s && match[:callback].present? == callback
  end

  def self.call(env)
    request = Rack::Request.new(env)
    # The SAML strategy also sets up for its other paths, like the metadata the app serves itself
    return unless (match = PATH.match(request.path))

    tenant = Tenant.find_by_host(request.host)
    identity_provider = ActsAsTenant.with_tenant(tenant) { IdentityProvider.enabled.find_by(protocol: match[:protocol], id: match[:id]) } if tenant

    raise ActiveRecord::RecordNotFound, "No identity provider at #{request.path}" unless identity_provider

    # Replaces whole option values: nested ones are shared with every other request
    env["omniauth.strategy"].options.merge!(identity_provider.strategy_options(request.base_url))
  end
end
