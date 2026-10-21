# A provider account (e.g. a Google login) the user can sign in with
class Identity < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :user
  # Set for providers the tenant registered (OIDC, SAML); nil for the app's own (e.g. developer)
  belongs_to :identity_provider, optional: true

  def provider_name = identity_provider&.name || provider.titleize

  after_create  { user.events.create! action: "provider_linked" }
  after_destroy { user.events.create! action: "provider_unlinked" }
end
