# An authorization code. Scoped to the tenant it was issued on, so it can't be
# redeemed on another tenant's host even by a global app.
class OauthAccessGrant < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant

  acts_as_tenant :tenant
  # The Locke session the user approved this from (Oauth::AuthorizationsController); copied onto the tokens
  belongs_to :session, optional: true
end
