require "rails_helper"

RSpec.describe LogoutToken do
  subject(:token) { described_class.new(issuer: "http://acme.localhost", audience: "client-id", sub: "usr_1", sid: "ses_1") }

  before_all { SigningKey.generate! }

  describe "#to_jwt" do
    subject(:decoded) do
      jwks = JWT::JWK::Set.new(Doorkeeper::OpenidConnect.signing_keys_normalized)
      JWT.decode(token.to_jwt, nil, true, algorithms: [ "RS256" ], jwks:)
    end

    it "is signed with the key that signs ID tokens, as a logout token" do
      claims, header = decoded

      expect(header).to include("typ" => "logout+jwt", "kid" => Doorkeeper::OpenidConnect.signing_key.kid)
      expect(claims).to include(
        "iss" => "http://acme.localhost", "aud" => "client-id", "sub" => "usr_1", "sid" => "ses_1",
        "events" => { "http://schemas.openid.net/event/backchannel-logout" => {} }
      )
      expect(claims).to include("jti", "iat", "exp").and not_include("nonce")
    end
  end

  describe "#claims" do
    it "expires soon after it's issued" do
      now = Time.current
      claims = token.claims(now:)

      expect(claims[:exp] - claims[:iat]).to eq(2.minutes.to_i)
    end

    it "is unique each time" do
      expect(token.claims[:jti]).not_to eq(token.claims[:jti])
    end
  end

  RSpec::Matchers.define_negated_matcher :not_include, :include
end
