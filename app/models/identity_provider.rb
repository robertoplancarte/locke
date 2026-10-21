# An OIDC or SAML identity provider a tenant registers, so its people can sign
# in with the tenant's own provider (Okta, Entra ID, Google Workspace...).
#
# Providers are saved disabled first: the redirect URL the provider needs is only
# known once the record has an id. They must be fully configured to be enabled.
class IdentityProvider < ApplicationRecord
  # Emails from SAML assertions arrive under different attribute names per provider
  SAML_ATTRIBUTE_STATEMENTS = {
    email: [ "email", "mail", "emailAddress", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" ],
    name: [ "name", "displayName", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name" ]
  }.freeze

  acts_as_tenant :tenant

  has_many :identities, dependent: :destroy

  enum :protocol, { oidc: "oidc", saml: "saml" }, validate: true

  encrypts :client_secret

  normalizes :name, :issuer, :client_id, :client_secret, :idp_entity_id, :idp_sso_url, :idp_certificate, with: ->(value) { value.strip.presence }

  scope :enabled, -> { where(enabled: true) }

  validates :name, presence: true
  validate :urls_are_https
  validates :issuer, :client_id, :client_secret, presence: true, if: -> { enabled? && oidc? }
  validates :idp_entity_id, :idp_sso_url, :idp_certificate, presence: true, if: -> { enabled? && saml? }
  validate :idp_certificate_is_a_certificate, if: :idp_certificate

  # Where sign-in starts; the callback and SAML metadata live underneath
  def auth_path = "/auth/#{protocol}/#{id}"

  def redirect_url(base_url) = "#{base_url}#{auth_path}/callback"

  def saml_metadata_url(base_url) = "#{base_url}#{auth_path}/metadata"

  # Options for the OmniAuth strategy of this provider's protocol, for a request to base_url
  def strategy_options(base_url)
    if oidc?
      {
        issuer:, discovery: true, response_type: "code", pkce: true, scope: %i[openid email profile],
        client_options: { identifier: client_id, secret: client_secret, redirect_uri: redirect_url(base_url) }
      }
    else
      {
        sp_entity_id: saml_metadata_url(base_url), assertion_consumer_service_url: redirect_url(base_url),
        idp_entity_id:, idp_sso_service_url: idp_sso_url, idp_cert: idp_certificate,
        attribute_statements: SAML_ATTRIBUTE_STATEMENTS, slo_enabled: false
      }
    end
  end

  private

  def urls_are_https
    %i[issuer idp_sso_url].each do |attribute|
      next if (url = public_send(attribute)).nil?

      uri = URI.parse(url) rescue nil
      errors.add(attribute, "must be an https:// URL") unless uri.is_a?(URI::HTTPS) && uri.host.present?
    end
  end

  def idp_certificate_is_a_certificate
    OpenSSL::X509::Certificate.new(idp_certificate)
  rescue OpenSSL::X509::CertificateError
    errors.add(:idp_certificate, "must be a PEM-encoded X.509 certificate")
  end
end
