require "rails_helper"

RSpec.describe "Authentication: tenant settings", type: :request do
  let!(:tenant) { create(:tenant, subdomain: "acme", **settings) }
  let(:settings) { {} }
  let(:user) { create(:user, tenant:) }

  before { host! "acme.localhost" }

  context "with sign-ups turned off" do
    let(:settings) { { sign_up_enabled: false } }

    it "hides the sign up link" do
      get sign_in_path

      expect(response.body).not_to include(sign_up_path)
    end

    it "turns away sign-ups" do
      expect {
        post sign_up_path, params: { email: "ada@example.com", password: "correct horse battery", password_confirmation: "correct horse battery" }
      }.not_to change { ActsAsTenant.with_tenant(tenant) { User.count } }

      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "with sign-in links turned off" do
    let(:settings) { { sign_in_links_enabled: false } }

    it "hides the button" do
      get sign_in_path

      expect(response.body).not_to include("Email me a sign-in link")
    end

    it "doesn't send links" do
      expect {
        post sessions_passwordless_path, params: { email: user.email }
      }.not_to have_enqueued_mail(UserMailer, :passwordless)

      expect(response).to redirect_to(sign_in_path)
    end

    it "rejects links sent before they were turned off" do
      token = user.sign_in_tokens.create!.signed_id(expires_in: 1.day)

      get edit_sessions_passwordless_path(sid: token)

      expect(response).to redirect_to(sign_in_path)
      expect(user.sessions).to be_empty
    end
  end

  context "with social sign-in turned off" do
    let(:settings) { { social_sign_in_enabled: false } }

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(provider: "developer", uid: "ada", info: { email: "ada@example.com" })
    end

    after do
      OmniAuth.config.mock_auth.delete(:developer)
      OmniAuth.config.test_mode = false
    end

    it "hides the providers" do
      get sign_in_path

      expect(response.body).not_to include("Or continue with")
    end

    it "doesn't sign in from a provider" do
      expect { post "/auth/developer/callback" }.not_to change { ActsAsTenant.with_tenant(tenant) { User.count } }

      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "with 2FA required" do
    let(:settings) { { two_factor: "required" } }

    before { sign_in_as user }

    it "sends users who haven't set it up to the setup page" do
      get root_path

      expect(response).to redirect_to(new_two_factor_authentication_profile_totp_path)
    end

    it "lets them set it up" do
      get new_two_factor_authentication_profile_totp_path

      expect(response).to have_http_status(:ok)
    end

    it "lets them log out" do
      delete session_path(user.sessions.sole)

      expect(user.sessions).to be_empty
    end

    it "lets users who have set it up in" do
      ActsAsTenant.with_tenant(tenant) { user.update!(otp_required_for_sign_in: true) }

      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "with 2FA turned off" do
    let(:settings) { { two_factor: "off" } }

    it "doesn't let users set it up" do
      sign_in_as user
      get new_two_factor_authentication_profile_totp_path

      expect(response).to redirect_to(root_path)
    end

    it "still asks users who set it up earlier for a code" do
      ActsAsTenant.with_tenant(tenant) { user.update!(otp_required_for_sign_in: true) }

      sign_in_as user

      expect(response).to redirect_to(new_two_factor_authentication_challenge_totp_path)
    end
  end
end
