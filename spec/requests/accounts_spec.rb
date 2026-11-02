require "rails_helper"

RSpec.describe "Account", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  describe "GET /account" do
    it "shows the preferences" do
      get account_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("(GMT+00:00) UTC", "Match my device", edit_account_path(field: "theme"))
    end
  end

  describe "GET /account/edit" do
    it "opens one preference for editing in place" do
      get edit_account_path(field: "time_zone")

      expect(response.body).to include('id="preference_time_zone"', '<option selected="selected" value="Etc/UTC">')
      expect(response.body).not_to include('id="user_theme_dark"')
    end

    it "ignores fields that aren't preferences" do
      get edit_account_path(field: "email")

      expect(response).to redirect_to(account_path)
    end
  end

  describe "GET /account/security" do
    it "shows how the user signs in" do
      create(:identity, user:, tenant:, provider: "github", email: "ada@work.example")

      get account_security_path

      expect(response.body).to include(edit_password_path, "Github", "ada@work.example", "Authenticator app")
    end

    it "offers to link the tenant's OIDC providers in a new tab" do
      oidc = create(:identity_provider, tenant:, name: "Okta")
      saml = create(:identity_provider, :saml, tenant:, name: "Entra ID")

      get account_security_path

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(%(form[action="#{oidc.auth_path}"][target="_blank"]))).to be_present
      expect(page.at_css(%(form[action="#{oidc.auth_path}"] input[name="link"][value="1"]))).to be_present
      expect(page.at_css(%(form[action="/auth/developer"][target="_blank"]))).to be_present
      expect(page.at_css(%(form[action="#{saml.auth_path}"]))).to be_nil
      expect(response.body).to include("Link Okta", "Link Developer")
    end

    it "removes a sign-in provider and comes back" do
      identity = create(:identity, user:, tenant:, provider: "github")

      delete identity_path(identity), headers: { "Referer" => account_security_url }

      expect(response).to redirect_to(account_security_url)
      expect(ActsAsTenant.with_tenant(tenant) { user.identities.exists? }).to be(false)
    end
  end

  describe "GET /account/activity" do
    it "shows the user's sessions and recent events" do
      get account_activity_path

      expect(response.body).to include("This device", "Signed in", authentications_events_path)
    end
  end

  describe "PATCH /account" do
    subject(:update_preferences) { patch account_path, params: { user: preferences } }

    let(:preferences) { { name: "Ada Lovelace", time_zone: "America/New_York", theme: "dark" } }

    it "saves them" do
      update_preferences

      expect(response).to redirect_to(account_path)
      expect(user.reload).to have_attributes(preferences)
    end

    it "applies them to every page" do
      update_preferences
      follow_redirect!

      expect(response.body).to include('data-theme="dark"', "Ada Lovelace")
    end

    it "shows times in the chosen zone" do
      update_preferences

      get sessions_path

      expect(response.body).to include(user.sessions.last.created_at.in_time_zone("America/New_York").to_s)
    end

    context "with an unknown time zone" do
      let(:preferences) { { time_zone: "Mars/Olympus_Mons" } }

      it "keeps the saved one" do
        update_preferences

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Time zone isn&#39;t a time zone we know", '<select autofocus="autofocus"')
        expect(user.reload.time_zone).to eq("Etc/UTC")
      end
    end

    it "doesn't change anything else" do
      patch account_path, params: { user: { email: "mallory@example.com", theme: "light" } }

      expect(user.reload).to have_attributes(email: user.email, theme: "light")
    end
  end
end
