# Base for Doorkeeper's browser-facing endpoints (/oauth/authorize). They run with
# the app's tenant, session cookie and sign-in page; who is signed in is decided
# by resource_owner_authenticator in config/initializers/doorkeeper.rb, which
# can also answer prompt=none without a redirect.
class OauthController < ApplicationController
  skip_before_action :authenticate, :require_two_factor_setup

  before_action :redirect_to_canonical_host

  private
    # Apps know a tenant by one issuer, so its other addresses send them there
    def redirect_to_canonical_host
      return if request.host == current_tenant.canonical_host

      redirect_to URI(request.url).tap { |url| url.host = current_tenant.canonical_host }.to_s, allow_other_host: true
    end
end
