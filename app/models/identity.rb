# A provider account (e.g. a Google login) the user can sign in with
class Identity < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :user
  # Set for providers the tenant registered (OIDC, SAML); nil for the app's own (e.g. developer)
  belongs_to :identity_provider, optional: true

  # As the provider last reported it, to tell accounts at the same provider apart
  encrypts :email
  normalizes :email, with: -> { _1.strip.downcase.presence }

  # Links a provider account to the user who asked for it, whatever its email, keeping the
  # email current. Nil when the provider account is already linked to someone else.
  def self.link(user, email:, **provider_account)
    identity = find_or_initialize_by(provider_account)
    return if identity.persisted? && identity.user_id != user.id

    identity.tap { it.update!(user:, email:) }
  end

  def provider_name = identity_provider&.name || provider.titleize

  # e.g. "Github (ada@example.com)"
  def label = email ? "#{provider_name} (#{email})" : provider_name

  after_create  { user.events.create! action: "provider_linked" }
  after_destroy { user.events.create! action: "provider_unlinked" }
end
