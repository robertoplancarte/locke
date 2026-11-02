# The JWT that tells an app a Locke session ended, signed like ID tokens and
# verifiable with the tenant's JWKS.
# https://openid.net/specs/openid-connect-backchannel-1_0.html#LogoutToken
LogoutToken = Data.define(:issuer, :audience, :sub, :sid) do
  self::EVENT = "http://schemas.openid.net/event/backchannel-logout"
  # Delivered straight away; a late retry shouldn't carry a long-lived token
  self::EXPIRY = 2.minutes

  def claims(now: Time.current)
    { iss: issuer, aud: audience, iat: now.to_i, exp: (now + self.class::EXPIRY).to_i, jti: SecureRandom.uuid,
      sub:, sid:, events: { self.class::EVENT => {} } }
  end

  # Never has a nonce, so it can't pass for an ID token
  def to_jwt(key: Doorkeeper::OpenidConnect.signing_key)
    JWT.encode(claims, key.signing_key, "RS256", { kid: key.kid, typ: "logout+jwt" })
  end
end
