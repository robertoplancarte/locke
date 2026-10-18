class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  set_current_tenant_through_filter
  # The tenant must be resolved first: users, and so sessions, belong to it
  before_action :set_tenant_from_host
  before_action :set_current_request_details
  before_action :authenticate
  before_action :require_two_factor_setup

  private

  # The bare root domain has no tenant; an unknown subdomain or domain is a 404.
  def set_tenant_from_host
    tenant = Tenant.find_by_host(request.host)
    raise ActiveRecord::RecordNotFound, "No tenant for #{request.host}" if tenant.nil? && !Tenant.root_host?(request.host)

    set_current_tenant(tenant)
  end

  def authenticate
    if session_record = find_session_record
      Current.session = session_record
    else
      redirect_to sign_in_path
    end
  end

  # Joining the tenant-scoped users means a session only counts on its own tenant's hosts
  def find_session_record
    Session.joins(:user).find_by(id: cookies.signed[:session_token])
  end

  # Tenants can require 2FA; until it's set up, signed-in users can only set it up or log out
  def require_two_factor_setup
    if Current.user&.must_set_up_two_factor?
      redirect_to new_two_factor_authentication_profile_totp_path, alert: "#{current_tenant.name} requires two-factor authentication. Set it up to continue."
    end
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end

  def require_sudo
    unless Current.session.sudo?
      redirect_to new_sessions_sudo_path(proceed_to_url: request.original_url)
    end
  end
end
