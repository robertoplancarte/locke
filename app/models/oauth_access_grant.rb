# An authorization code. Scoped to the tenant it was issued on, so it can't be
# redeemed on another tenant's host even by a global app.
class OauthAccessGrant < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant

  acts_as_tenant :tenant
  # The Locke session the user approved this from; copied onto the tokens
  belongs_to :session, optional: true

  # Always the current session, whatever the authorization request asked for
  before_validation(on: :create) { self.session = Current.session }
end
