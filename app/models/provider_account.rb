# What a provider (the app's own, like GitHub, or one a tenant registered) says
# about who someone is, and the rules for which Locke account that is.
#
# Matching accounts by email is only safe because every configured provider
# verifies the emails it returns; otherwise anyone could claim an account by
# asserting its email. Providers a tenant registers are trusted with its own
# accounts, as the tenant chose them. Users and identities are tenant-scoped, so
# matching only ever looks inside the current tenant.
class ProviderAccount
  # What signing in with this provider account comes to:
  #   :sign_in  sign in as user, who may be new or have unsaved changes
  #   :linked   identity was linked to the signed-in user instead
  #   :closed   no account, and the provider can't create one
  Match = Data.define(:outcome, :user, :identity)

  attr_reader :provider, :uid, :email, :name, :identity_provider

  def initialize(tenant:, provider:, uid:, email:, name: nil, identity_provider: nil)
    @tenant, @provider, @uid, @email, @name, @identity_provider = tenant, provider, uid, email, name, identity_provider
  end

  # In order: whoever already has this provider account, an account with the
  # same email (now verified, as the provider vouched for it), the signed-in
  # user, or a new account when the provider may create one. A tenant's provider
  # manages the accounts it creates, and keeps them up to date on every sign-in.
  def match(signed_in_user: nil)
    if identity
      identity.update!(email:)
      Match.new(:sign_in, keep_current(identity.user), identity)
    elsif (user = User.find_by(email:))
      user.verified = true
      Match.new(:sign_in, user, user.identities.build(identity_attributes))
    elsif signed_in_user
      Match.new(:linked, signed_in_user, signed_in_user.identities.create!(identity_attributes))
    elsif creates_users?
      user = User.new(email:, name:, password: SecureRandom.base58, verified: true, managed_by: identity_provider)
      Match.new(:sign_in, user, user.identities.build(identity_attributes))
    else
      Match.new(:closed, nil, nil)
    end
  end

  # A tenant's own provider has its own switch, as tenants that turn sign-ups off
  # often still want their provider to create accounts; the app's providers follow sign-ups.
  def creates_users?
    identity_provider ? identity_provider.creates_users? : @tenant.sign_up_enabled?
  end

  # What identifies the account: the same uid at two providers is two accounts
  def key = { provider:, uid:, identity_provider: }

  private
    # The name and email the provider has now, for an account it manages. An email
    # another account already has is left alone, and reported for someone to sort out.
    def keep_current(user)
      return user unless identity_provider && user.managed_by_id == identity_provider.id

      attributes = { name: name.presence || user.name }
      if email.present? && email != user.email
        if User.where.not(id: user.id).exists?(email:)
          ProvisioningIssue.report(identity_provider:, user:, source: :sign_in, details: { email: },
            message: "#{identity_provider.name} says #{user.email} is now #{email}, but another account already has that email")
        else
          attributes[:email] = email
        end
      end

      user.tap { it.update_from_provider(attributes) }
    end

    def identity
      return @identity if defined?(@identity)

      @identity = Identity.find_by(key)
    end

    def identity_attributes = key.merge(email:)
end
