# The one way into an account. Every sign-in method hands the user it proved to
# a SignIn, which decides whether that's enough or a second factor is still owed,
# and then starts the session, recording how and when the user signed in.
#
# Methods are RFC 8176 amr values, which an OIDC provider reports as is:
#   pwd    a password
#   email  a sign-in link sent by email (not in RFC 8176)
#   fed    an external identity provider, the tenant's own or a social one
#   otp    a code from an authenticator app
#   hwk    a security key
#   rc     a recovery code (not in RFC 8176)
#   mfa    added whenever more than one method was used
class SignIn
  # Proving any of these after another method completes 2FA
  SECOND_FACTORS = %w[otp hwk rc].freeze

  CHALLENGE_PURPOSE = :sign_in_challenge
  CHALLENGE_EXPIRY = 20.minutes

  attr_reader :user, :amr, :identity_provider

  # A sign-in that's waiting on its second factor, or nil once the token is
  # invalid or expired. Users and providers are tenant-scoped, so a token only
  # works on its own tenant's hosts.
  def self.from_challenge_token(token)
    return unless token.is_a?(String) && (data = verifier.verified(token, purpose: CHALLENGE_PURPOSE))
    return unless (user = User.find_by(id: data["user_id"]))

    new(user, amr: data["amr"], identity_provider: IdentityProvider.find_by(id: data["identity_provider_id"]))
  end

  def self.verifier = Rails.application.message_verifier(CHALLENGE_PURPOSE)

  def initialize(user, method: nil, amr: [ method ], identity_provider: nil)
    @user, @amr, @identity_provider = user, Array(amr).compact.map(&:to_s), identity_provider
  end

  # No first factor counts as strong enough on its own: users who set up 2FA
  # are asked for it however they signed in, sign-in links and providers included.
  def second_factor_required?
    user.otp_required_for_sign_in? && amr.intersection(SECOND_FACTORS).none?
  end

  # Carries the sign-in through the 2FA challenge, kept in the Rails session
  def challenge_token
    self.class.verifier.generate({ user_id: user.id, amr:, identity_provider_id: identity_provider&.id },
      purpose: CHALLENGE_PURPOSE, expires_in: CHALLENGE_EXPIRY)
  end

  def with_second_factor(method)
    raise ArgumentError, "#{method} isn't a second factor" unless method.to_s.in?(SECOND_FACTORS)

    self.class.new(user, amr: amr | [ method.to_s ], identity_provider:)
  end

  def complete!
    raise "A second factor is still required" if second_factor_required?

    user.sessions.create!(authenticated_at: Time.current, identity_provider:, amr: amr.many? ? amr | [ "mfa" ] : amr).tap do
      # Break-glass use: the tenant sends everyone to its provider, and this didn't come through it
      user.events.create!(action: "signed_in_without_default_provider") if bypassed_default_provider?
    end
  end

  private
    def bypassed_default_provider?
      (default_id = user.tenant.default_identity_provider_id) && identity_provider&.id != default_id
    end
end
