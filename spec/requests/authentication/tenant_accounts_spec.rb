require "rails_helper"

RSpec.describe "Authentication: accounts belong to one tenant", type: :request do
  let_it_be(:acme) { create(:tenant, subdomain: "acme") }
  let_it_be(:globex) { create(:tenant, subdomain: "globex") }
  let_it_be(:user) { create(:user, tenant: acme, email: "ada@example.com") }

  describe "POST /sign_up" do
    subject(:sign_up) { post sign_up_path, params: { email: "ada@example.com", password: "another long password", password_confirmation: "another long password" } }

    it "accepts an email already registered on another tenant" do
      host! "globex.localhost"

      expect { sign_up }.to change { ActsAsTenant.with_tenant(globex) { User.count } }.by(1)
      expect(response).to redirect_to(root_path)
    end

    it "rejects an email already registered on the same tenant" do
      host! "acme.localhost"

      expect { sign_up }.not_to change { ActsAsTenant.with_tenant(acme) { User.count } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /sign_in" do
    before { host! "acme.localhost" }

    it "shows the form to signed out visitors" do
      get sign_in_path

      expect(response).to have_http_status(:ok)
    end

    it "sends signed in users home" do
      sign_in_as user
      get sign_in_path

      expect(response).to redirect_to(root_path)
    end

    it "shows the form to users signed in on another tenant" do
      sign_in_as user
      host! "globex.localhost"
      get sign_in_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /sign_in" do
    it "signs in on the user's own tenant" do
      host! "acme.localhost"
      sign_in_as user

      expect(response).to redirect_to(root_path)
    end

    it "does not find the user on another tenant" do
      host! "globex.localhost"
      sign_in_as user

      expect(response).to redirect_to(sign_in_path(email_hint: user.email))
    end
  end

  describe "GET /identity/password_reset/edit" do
    it "rejects a reset link used on another tenant" do
      token = user.generate_token_for(:password_reset)
      host! "globex.localhost"

      get edit_identity_password_reset_path(sid: token)

      expect(response).to redirect_to(new_identity_password_reset_path)
    end
  end

  describe "GET /sessions/passwordless/edit" do
    it "rejects a sign in link used on another tenant" do
      token = user.sign_in_tokens.create!.signed_id(expires_in: 1.day)
      host! "globex.localhost"

      get edit_sessions_passwordless_path(sid: token)

      expect(response).to redirect_to(sign_in_path)
    end
  end

  it "has no sign in on the root domain" do
    host! "localhost"
    get "/sign_in"

    expect(response).to have_http_status(:not_found)
  end
end
