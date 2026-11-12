# Applies what a tenant's identity provider says about one of its users, as its
# SCIM client sends it: creates the account or brings it up to date, and
# deactivates or reactivates it. The provider then manages the account, so its
# person can only sign in through it (see SignIn#refusal).
#
# Attributes are the ones the provider sent, of email, name, external_id and
# active; the ones it left out stay as they are. Whatever can't be applied is
# left on the user's errors and reported as a ProvisioningIssue.
class UserProvisioning
  attr_reader :identity_provider

  def initialize(identity_provider)
    @identity_provider = identity_provider
  end

  # Takes over an existing account with the same email, as the provider vouches for it
  def create(attributes)
    user = User.find_by(email: attributes[:email]) if attributes[:email].present?
    apply(user || User.new(password: SecureRandom.base58, verified: true), attributes)
  end

  def update(user, attributes) = apply(user, attributes)

  private
    def apply(user, attributes)
      if user.managed_by && user.managed_by != identity_provider
        user.errors.add(:base, :managed_elsewhere, message: "#{user.managed_by.name} manages this account")
      else
        User.transaction do
          if user.update_from_provider(attributes.slice(:email, :name, :external_id).merge(managed_by: identity_provider))
            attributes[:active] ? user.reactivate : user.deactivate if attributes.key?(:active)
          end
        end
      end

      user.tap { report(it, attributes) if it.errors.any? }
    end

    def report(user, attributes)
      action = user.persisted? ? "update #{user.email_was}" : "add #{attributes[:email] || "a user"}"
      ProvisioningIssue.report(identity_provider:, user: user.persisted? ? user : nil, source: :scim,
        message: "#{identity_provider.name} couldn't #{action}: #{user.errors.full_messages.to_sentence}",
        details: attributes.except(:active).compact)
    end
end
