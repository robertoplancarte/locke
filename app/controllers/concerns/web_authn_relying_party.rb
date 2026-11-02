# Security keys are bound to the host they were registered on, so each tenant host
# (subdomain or custom domain) is its own relying party.
module WebAuthnRelyingParty
  extend ActiveSupport::Concern

  private

  def relying_party
    @relying_party ||= WebAuthn::RelyingParty.new(
      id: request.host,
      allowed_origins: [ request.base_url ],
      name: current_tenant.name
    )
  end
end
