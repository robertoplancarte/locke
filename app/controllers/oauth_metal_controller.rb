# Base for the OAuth and OpenID Connect endpoints apps call from their servers:
# token, revoke, introspect, userinfo, discovery and JWKS. No cookies or CSRF,
# but the same tenant from the host, so tokens and codes stay in their tenant.
class OauthMetalController < ActionController::API
  include TenantFromHost

  before_action :require_tenant

  private
    # The bare root domain has no tenant, and so no issuer
    def require_tenant
      head :not_found unless current_tenant
    end
end
