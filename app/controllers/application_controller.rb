class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  before_action :set_tenant_from_host

  private

  # The bare root domain has no tenant; an unknown subdomain or domain is a 404.
  def set_tenant_from_host
    tenant = Tenant.find_by_host(request.host)
    raise ActiveRecord::RecordNotFound, "No tenant for #{request.host}" if tenant.nil? && !Tenant.root_host?(request.host)

    set_current_tenant(tenant)
  end
end
