require "rails_helper"

RSpec.describe "Settings: identity providers", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  def identity_providers = ActsAsTenant.with_tenant(tenant) { IdentityProvider.all.to_a }

  describe "GET /settings/identity_providers" do
    it "lists only this tenant's providers" do
      create(:identity_provider, tenant:, name: "Okta")
      create(:identity_provider, name: "Someone else's")

      get settings_identity_providers_path

      expect(response.body).to include("Okta")
      expect(response.body).not_to include("Someone else&#39;s")
    end

    it "links to the form for each protocol" do
      get settings_identity_providers_path

      expect(response.body).to include(%(href="/settings/identity_providers/new?protocol=oidc"))
      expect(response.body).to include(%(href="/settings/identity_providers/new?protocol=saml"))
    end
  end

  describe "GET /settings/identity_providers/new" do
    it "shows the SAML form for a SAML provider" do
      get new_settings_identity_provider_path(params: { protocol: "saml" })

      expect(response.body).to include("Add SAML provider", "Single sign-on URL")
      expect(response.body).not_to include("Client ID")
    end
  end

  describe "POST /settings/identity_providers" do
    it "saves the provider turned off and shows what to set up next" do
      post settings_identity_providers_path, params: { identity_provider: { protocol: "saml", name: "Entra ID" } }

      identity_provider = identity_providers.sole
      expect(identity_provider).to have_attributes(name: "Entra ID", protocol: "saml", enabled: false)
      expect(response).to redirect_to(edit_settings_identity_provider_path(identity_provider))

      follow_redirect!
      expect(response.body).to include("http://acme.localhost/auth/saml/#{identity_provider.id}/callback")
    end

    it "can't be turned on before it's configured" do
      post settings_identity_providers_path, params: { identity_provider: { protocol: "oidc", name: "Okta", enabled: "1" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(identity_providers).to be_empty
    end
  end

  describe "PATCH /settings/identity_providers/:id" do
    let_it_be(:identity_provider) { create(:identity_provider, tenant:, client_secret: "s3cret") }

    it "keeps the saved secret when it's left blank" do
      patch settings_identity_provider_path(identity_provider), params: { identity_provider: { client_id: "new-client", client_secret: "", protocol: "saml" } }

      expect(response).to redirect_to(settings_identity_providers_path)
      expect(identity_provider.reload).to have_attributes(client_id: "new-client", client_secret: "s3cret", protocol: "oidc")
    end

    it "never shows the saved secret" do
      get edit_settings_identity_provider_path(identity_provider)

      expect(response.body).not_to include("s3cret")
    end
  end

  describe "DELETE /settings/identity_providers/:id" do
    it "removes the provider and the identities linked through it" do
      identity_provider = create(:identity_provider, tenant:)
      create(:identity, user:, tenant:, provider: "oidc", identity_provider:)

      delete settings_identity_provider_path(identity_provider)

      expect(response).to redirect_to(settings_identity_providers_path)
      expect(identity_providers).to be_empty
      expect(ActsAsTenant.with_tenant(tenant) { user.identities.exists? }).to be(false)
    end

    it "can't remove another tenant's provider" do
      delete settings_identity_provider_path(create(:identity_provider))

      expect(response).to have_http_status(:not_found)
    end
  end
end
