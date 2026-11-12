# Something an identity provider told Locke about a user that Locke couldn't
# apply, like an email another account already has, for the people managing the
# tenant's users to sort out. Reporting the same problem again counts another
# occurrence of the unresolved issue instead of opening a new one.
class ProvisioningIssue < ApplicationRecord
  acts_as_tenant :tenant

  belongs_to :identity_provider, optional: true
  belongs_to :user, optional: true

  # scim: the provider's SCIM client; sign_in: someone signing in with the provider
  enum :source, { scim: "scim", sign_in: "sign_in" }, prefix: true, validate: true

  validates :message, presence: true

  scope :unresolved, -> { where(resolved_at: nil) }

  def self.report(identity_provider:, source:, message:, user: nil, details: {})
    issue = unresolved.find_or_initialize_by(identity_provider:, user:, source:, message:)
    issue.occurrences += 1 if issue.persisted?
    issue.tap { it.update!(details:, last_occurred_at: Time.current) }
  end

  def resolve = update!(resolved_at: Time.current)
end
