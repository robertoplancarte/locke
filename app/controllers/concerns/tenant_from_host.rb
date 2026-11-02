# Resolves the current tenant from the request's host, for every controller:
# the app's own, and the OAuth endpoints apps call from their servers.
module TenantFromHost
  extend ActiveSupport::Concern

  included do
    set_current_tenant_through_filter
    before_action :set_tenant_from_host
    before_action { Current.oidc_issuer = current_tenant.oidc_issuer(**Rails.configuration.x.public_url_options) if current_tenant }
  end

  private
    # The bare root domain has no tenant; an unknown subdomain or domain is a 404.
    # A tenant's old subdomain redirects to its current address.
    def set_tenant_from_host
      tenant = Tenant.find_by_host(request.host)
      if tenant.nil? && (moved_tenant = Tenant.find_by_retired_host(request.host))
        return redirect_to_current_host(moved_tenant)
      end

      raise ActiveRecord::RecordNotFound, "No tenant for #{request.host}" if tenant.nil? && !Tenant.root_host?(request.host)

      set_current_tenant(tenant)
    end

    # Temporary, so browsers don't cache it: the tenant may move back to this subdomain later.
    # 307 keeps the method and body of anything but a GET.
    def redirect_to_current_host(tenant)
      url = URI(request.url).tap { it.host = tenant.host }.to_s
      redirect_to url, allow_other_host: true, status: request.get? || request.head? ? :found : :temporary_redirect
    end
end
