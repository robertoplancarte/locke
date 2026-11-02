class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent, :ip_address
  # The current tenant's OpenID Connect issuer URL
  attribute :oidc_issuer

  delegate :user, to: :session, allow_nil: true
end
