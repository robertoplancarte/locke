require "rails_helper"

RSpec.describe "Settings: authentication", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  describe "GET /settings/authentication/edit" do
    it "shows the current settings" do
      get edit_settings_authentication_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<input[^>]*checked="checked"[^>]*id="tenant_two_factor_optional"/)
    end
  end

  describe "PATCH /settings/authentication" do
    it "saves the settings" do
      patch settings_authentication_path, params: { tenant: { sign_up_enabled: "0", sign_in_links_enabled: "0", social_sign_in_enabled: "0", two_factor: "required" } }

      expect(response).to redirect_to(edit_settings_authentication_path)
      expect(tenant.reload).to have_attributes(sign_up_enabled: false, sign_in_links_enabled: false, social_sign_in_enabled: false, two_factor: "required")
    end

    it "rejects an unknown 2FA setting" do
      patch settings_authentication_path, params: { tenant: { two_factor: "sometimes" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(tenant.reload.two_factor).to eq("optional")
    end
  end
end
