require "rails_helper"

# Every sign-in method goes through SignIn: users with 2FA are challenged however
# they signed in, and everyone lands back on the page that sent them to sign in.
RSpec.describe "Authentication: one way to sign in", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:, email: "ada@example.com", otp_required_for_sign_in: true) }

  before { host! "acme.localhost" }

  def totp_code = ROTP::TOTP.new(user.otp_secret).now
  def last_session = ActsAsTenant.with_tenant(tenant) { user.sessions.includes(:identity_provider).sole }

  describe "a deep link" do
    it "comes back after the password and the TOTP challenge" do
      get account_path(tab: "security")
      expect(response).to redirect_to(sign_in_path)

      sign_in_as user
      expect(response).to redirect_to(new_two_factor_authentication_challenge_totp_path)

      post two_factor_authentication_challenge_totp_path, params: { code: totp_code }
      expect(response).to redirect_to(account_path(tab: "security"))
      expect(last_session).to have_attributes(amr: %w[pwd otp mfa], authenticated_at: be_present)
    end

    it "isn't kept for form posts" do
      delete session_path(1)

      sign_in_as user
      post two_factor_authentication_challenge_totp_path, params: { code: totp_code }
      expect(response).to redirect_to(root_path)
    end

    %w[//evil.example /\\evil.example https://evil.example].each do |return_to|
      it "doesn't send anyone to #{return_to}" do
        # Planted however it got there, it's checked on the way out
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).and_call_original
        allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:return_to).and_return(return_to)

        sign_in_as user
        post two_factor_authentication_challenge_totp_path, params: { code: totp_code }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "a sign-in link" do
    let(:link_token) { ActsAsTenant.with_tenant(tenant) { user.sign_in_tokens.create!.signed_id(expires_in: 1.day) } }

    it "still asks users with 2FA for their second factor" do
      get edit_sessions_passwordless_path(sid: link_token)

      expect(response).to redirect_to(new_two_factor_authentication_challenge_totp_path)
      expect(user.sessions).to be_empty

      post two_factor_authentication_challenge_totp_path, params: { code: totp_code }
      expect(last_session.amr).to eq(%w[email otp mfa])
    end

    it "can't be used again while the challenge is pending" do
      token = link_token
      get edit_sessions_passwordless_path(sid: token)
      get edit_sessions_passwordless_path(sid: token)

      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "an identity provider" do
    let_it_be(:okta) { create(:identity_provider, tenant:, name: "Okta") }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(provider: "oidc", uid: "ada-sub", info: { email: "ada@example.com", email_verified: true })
    end

    after do
      OmniAuth.config.mock_auth.delete(:oidc)
      OmniAuth.config.test_mode = false
    end

    it "still asks users with 2FA for their second factor, and remembers the provider" do
      get "#{okta.auth_path}/callback"

      expect(response).to redirect_to(new_two_factor_authentication_challenge_totp_path)
      expect(user.sessions).to be_empty

      post two_factor_authentication_challenge_totp_path, params: { code: totp_code }
      expect(last_session).to have_attributes(amr: %w[fed otp mfa], identity_provider: okta)
    end

    it "doesn't sign in before the challenge" do
      get "#{okta.auth_path}/callback"
      get root_path

      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "a SAML provider" do
    let_it_be(:saml) { create(:identity_provider, :saml, tenant:, name: "Entra ID") }
    let_it_be(:user) { create(:user, tenant:, email: "grace@example.com") }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:saml] = OmniAuth::AuthHash.new(provider: "saml", uid: "grace", info: { email: "grace@example.com" })
    end

    after do
      OmniAuth.config.mock_auth.delete(:saml)
      OmniAuth.config.test_mode = false
    end

    # Its response is posted cross-site, which leaves out the session cookie holding return_to
    it "brings return_to back through RelayState" do
      get "#{saml.auth_path}/callback", params: { RelayState: "/account" }

      expect(response).to redirect_to("/account")
    end
  end

  # Which accounts may sign in is SignIn#refusal's call, covered in spec/models/sign_in_spec.rb
  describe "an account Locke won't sign in" do
    let_it_be(:identity_provider) { create(:identity_provider, tenant:, name: "Keycloak") }
    let_it_be(:managed) { create(:user, tenant:, managed_by: identity_provider) }

    it "is sent back to the sign-in page with the reason" do
      sign_in_as managed

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:alert]).to include("Sign in with Keycloak")
    end

    it "loses a session it already has once deactivated" do
      grace = create(:user, tenant:)
      sign_in_as grace
      ActsAsTenant.with_tenant(tenant) { grace.update_column(:deactivated_at, Time.current) }

      get account_path

      expect(response).to redirect_to(sign_in_path)
    end
  end
end
