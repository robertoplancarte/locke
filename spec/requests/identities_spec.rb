require "rails_helper"

RSpec.describe "Identities", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  describe "GET /identities" do
    it "lists the user's providers" do
      create(:identity, user:, provider: "github")

      get identities_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Github")
    end
  end

  describe "GET /identities/:id/linked" do
    let_it_be(:identity) { create(:identity, user:, provider: "github", email: "ada@example.com") }
    let_it_be(:other_identity) { create(:identity, user: create(:user, tenant:)) }

    it "says the provider account is linked, with a way back to settings" do
      get linked_identity_path(identity)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Your Github account is linked", "Github (ada@example.com)", "You can close this tab now", account_security_path)
    end

    it "doesn't show another user's provider" do
      get linked_identity_path(other_identity)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /identities/:id" do
    it "unlinks the provider" do
      identity = create(:identity, user:, provider: "github")

      expect { delete identity_path(identity) }.to change { ActsAsTenant.with_tenant(tenant) { user.identities.count } }.by(-1)

      expect(response).to redirect_to(identities_path)
      expect(user.events.pluck(:action)).to include("provider_unlinked")
    end

    it "can't unlink another user's provider" do
      identity = create(:identity, user: create(:user, tenant:))

      delete identity_path(identity)

      expect(response).to have_http_status(:not_found)
      expect(ActsAsTenant.with_tenant(tenant) { Identity.exists?(identity.id) }).to be(true)
    end
  end
end
