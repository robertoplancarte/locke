require "rails_helper"
require "webauthn/fake_client"

RSpec.describe "Two-factor authentication: security keys", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

  # A software authenticator holding a real key pair, talking to the acme host
  let(:authenticator) { WebAuthn::FakeClient.new("http://acme.localhost") }

  before { host! "acme.localhost" }

  def assertion_for(authenticator)
    get new_two_factor_authentication_challenge_security_keys_path, headers: { "Accept" => "application/json" }
    authenticator.get(challenge: response.parsed_body["challenge"])
  end

  def submit(credential)
    post two_factor_authentication_challenge_security_keys_path, as: :json, params: { credential: }
  end

  describe "registering a key" do
    let(:user) { create(:user, tenant:) }

    before { sign_in_as user }

    it "stores the key's public key" do
      get new_two_factor_authentication_profile_security_key_path, headers: { "Accept" => "application/json" }
      credential = authenticator.create(challenge: response.parsed_body["challenge"])

      post two_factor_authentication_profile_security_keys_path, as: :json, params: { credential: }

      expect(response).to have_http_status(:created)
      expect(user.security_keys.sole).to have_attributes(external_id: credential["id"], public_key: be_present)
    end

    it "rejects a key that didn't answer the challenge it was given" do
      get new_two_factor_authentication_profile_security_key_path, headers: { "Accept" => "application/json" }
      credential = authenticator.create(challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false))

      post two_factor_authentication_profile_security_keys_path, as: :json, params: { credential: }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.security_keys).to be_empty
    end
  end

  describe "signing in with a key" do
    let(:user) { create(:user, tenant:, otp_required_for_sign_in: true) }

    before do
      relying_party = WebAuthn::RelyingParty.new(id: "acme.localhost", allowed_origins: [ "http://acme.localhost" ])
      challenge = relying_party.options_for_registration(user: { id: user.webauthn_id, name: user.email }).challenge
      credential = relying_party.verify_registration(authenticator.create(challenge:), challenge)
      user.security_keys.create!(name: "YubiKey", external_id: credential.id, public_key: credential.public_key, sign_count: credential.sign_count)

      sign_in_as user
    end

    it "signs in with the registered key" do
      submit assertion_for(authenticator)

      expect(response).to have_http_status(:created)
      expect(user.sessions).to be_present
    end

    # Someone who knows only the password gets the key's ID from the challenge options,
    # then answers with an assertion no authenticator signed
    it "doesn't sign in with a forged assertion for a registered key" do
      get new_two_factor_authentication_challenge_security_keys_path, headers: { "Accept" => "application/json" }
      key_id = response.parsed_body["allowCredentials"].sole["id"]

      forged = Base64.urlsafe_encode64("forged", padding: false)
      submit({ type: "public-key", id: key_id, rawId: key_id, response: { authenticatorData: forged, clientDataJSON: forged, signature: forged } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.sessions).to be_empty
    end

    it "doesn't sign in with a key that was never registered" do
      unregistered = WebAuthn::FakeClient.new("http://acme.localhost").tap(&:create)

      submit assertion_for(unregistered)

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.sessions).to be_empty
    end

    it "doesn't accept the same assertion twice" do
      assertion = assertion_for(authenticator)
      submit assertion
      # Signing in again starts a new challenge the old assertion didn't answer
      user.sessions.delete_all
      sign_in_as user

      submit assertion

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.sessions).to be_empty
    end
  end
end
