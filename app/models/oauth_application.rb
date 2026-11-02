# An app that signs people in with Locke over OpenID Connect.
#
# A tenant's own app (tenant_id set) only works on that tenant's hosts. A global
# app (no tenant) works on every tenant's host: the first-party apps. Either
# way, its grants and tokens belong to the tenant they were issued on, and the
# uid (client_id) is unique across all of them, so no tenant can shadow a
# global app.
class OauthApplication < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

  acts_as_tenant :tenant, has_global_records: true, optional: true

  validate :backchannel_logout_uri_is_https, if: :backchannel_logout_uri
  validate :post_logout_redirect_uris_are_absolute

  normalizes :backchannel_logout_uri, with: -> { _1.strip.presence }
  normalizes :post_logout_redirect_uris, with: -> { Array(_1).map(&:strip).compact_blank }

  def global? = tenant_id.nil?

  # Only an exact match, as for redirect_uri
  def post_logout_redirect_uri?(uri) = uri.is_a?(String) && post_logout_redirect_uris.include?(uri)

  def log_out_later(tenant, sub:, sid:)
    Oauth::BackchannelLogoutJob.perform_later(tenant, id, sub:, sid:)
  end

  # Tells the app that a Locke session ended (OIDC Back-Channel Logout 1.0), so
  # it ends the sessions it started from it
  def log_out!(tenant, sub:, sid:, client: Oauth::BackchannelLogoutClient.new)
    token = LogoutToken.new(issuer: tenant.oidc_issuer(**Rails.configuration.x.public_url_options), audience: uid, sub:, sid:)
    client.deliver(backchannel_logout_uri, token.to_jwt)
  end

  private
    # Logout tokens carry a session's sid, so they only travel encrypted (plain http is fine in development)
    def backchannel_logout_uri_is_https
      return if absolute_url?(backchannel_logout_uri) && (URI(backchannel_logout_uri).scheme == "https" || Rails.env.local?)

      errors.add(:backchannel_logout_uri, "must be an https URL")
    end

    def post_logout_redirect_uris_are_absolute
      errors.add(:post_logout_redirect_uris, "must be absolute URLs") unless post_logout_redirect_uris.all? { |uri| absolute_url?(uri) }
    end

    def absolute_url?(uri)
      URI.parse(uri).absolute?
    rescue URI::InvalidURIError
      false
    end
end
