require "rails_helper"

# A tenant can send everyone straight to one of its providers. Locke's own form
# stays behind ?local=1 (break-glass), and each sign-in that bypasses the provider is logged.
RSpec.describe "Authentication: a tenant's default identity provider", type: :request do
  # Examples disable and delete them, so each starts from a fresh copy
  let_it_be(:tenant, refind: true) { create(:tenant, subdomain: "acme") }
  let_it_be(:okta, refind: true) { create(:identity_provider, tenant:, name: "Okta") }
  let_it_be(:user) { create(:user, tenant:, email: "ada@example.com") }

  before do
    host! "acme.localhost"
    tenant.update!(default_identity_provider: okta)
  end

  def events_of(user) = ActsAsTenant.with_tenant(tenant) { user.events.pluck(:action) }

  describe "the sign-in page" do
    it "sends people straight to the provider" do
      get sign_in_path

      expect(response.body).to include(%(action="#{okta.auth_path}")).and include(%(data-controller="auto-submit"))
      expect(response.body).not_to include("Password")
    end

    it "shows the form at ?local=1" do
      get sign_in_path(local: 1)

      expect(response.body).to include("Password").and include(okta.auth_path)
      expect(response.body).not_to include("auto-submit")
    end

    it "doesn't send people back to a provider that just turned them away" do
      get "/auth/failure", params: { message: "invalid_credentials" }
      follow_redirect!

      expect(response.body).to include("invalid_credentials").and include("Continue with Okta")
      expect(response.body).not_to include("auto-submit")
    end

    it "doesn't sign people straight back in after they log out" do
      sign_in_as user
      delete session_path(ActsAsTenant.with_tenant(tenant) { user.sessions.sole })
      follow_redirect! while response.redirect?

      expect(response.body).to include("That session has been logged out").and include("Continue with Okta")
      expect(response.body).not_to include("auto-submit")
    end

    it "shows the form for everyone once the provider is disabled" do
      ActsAsTenant.with_tenant(tenant) { okta.update!(enabled: false) }

      get sign_in_path

      expect(tenant.reload.default_identity_provider_id).to be_nil
      expect(response.body).to include("Password")
    end
  end

  describe "break-glass sign-in" do
    it "signs in with a password and logs that it bypassed the provider" do
      sign_in_as user

      expect(response).to redirect_to(root_path)
      expect(events_of(user)).to include("signed_in_without_default_provider")
    end

    it "still asks users with 2FA for their second factor" do
      ActsAsTenant.with_tenant(tenant) { user.update!(otp_required_for_sign_in: true) }

      sign_in_as user

      expect(response).to redirect_to(new_two_factor_authentication_challenge_totp_path)
      expect(user.sessions).to be_empty
    ensure
      ActsAsTenant.with_tenant(tenant) { user.update!(otp_required_for_sign_in: false) }
    end

    it "keeps the form after a wrong password" do
      post sign_in_path, params: { email: user.email, password: "wrong" }

      expect(response).to redirect_to(sign_in_path(email_hint: user.email, local: 1))
    end
  end

  describe "signing in through the provider" do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(provider: "oidc", uid: "ada-sub", info: { email: "ada@example.com", email_verified: true })
    end

    after do
      OmniAuth.config.mock_auth.delete(:oidc)
      OmniAuth.config.test_mode = false
    end

    it "isn't logged as break-glass" do
      get "#{okta.auth_path}/callback"

      expect(user.sessions).to exist
      expect(events_of(user)).not_to include("signed_in_without_default_provider")
    end
  end

  describe "choosing it" do
    let(:other_tenant) { create(:tenant) }

    it "must be one of the tenant's own providers" do
      foreign = create(:identity_provider, tenant: other_tenant)

      expect(tenant.update(default_identity_provider_id: foreign.id)).to be(false)
      expect(tenant.errors[:default_identity_provider]).to be_present
    end

    it "must be enabled" do
      disabled = create(:identity_provider, tenant:, enabled: false)

      expect(tenant.update(default_identity_provider_id: disabled.id)).to be(false)
    end

    it "falls back to Locke's form when the provider is deleted" do
      ActsAsTenant.with_tenant(tenant) { okta.destroy! }

      expect(tenant.reload.default_identity_provider_id).to be_nil
    end

    it "is set in the authentication settings" do
      tenant.update!(default_identity_provider: nil)
      sign_in_as user

      patch settings_authentication_path, params: { tenant: { default_identity_provider_id: okta.id } }

      expect(tenant.reload.default_identity_provider_id).to eq(okta.id)
      get edit_settings_authentication_path
      expect(response.body).to include("Sign in another way")
    end
  end
end
