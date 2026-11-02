# An access (and refresh) token, scoped to the tenant it was issued on
class OauthAccessToken < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

  acts_as_tenant :tenant
  # Copied from the grant, and from token to token on refresh
  belongs_to :session, optional: true
end
