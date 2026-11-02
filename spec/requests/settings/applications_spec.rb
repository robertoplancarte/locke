require "rails_helper"

RSpec.describe "Settings: apps", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  def applications = ActsAsTenant.without_tenant { OauthApplication.where(tenant:).to_a }

  describe "GET /settings/applications" do
    it "lists only this tenant's apps, not other tenants' or the global ones" do
      create(:oauth_application, tenant:, name: "Intranet")
      create(:oauth_application, tenant: create(:tenant), name: "Someone else's")
      create(:oauth_application, name: "Global app")

      get settings_applications_path

      expect(response.body).to include("Intranet")
      expect(response.body).not_to include("Someone else&#39;s")
      expect(response.body).not_to include("Global app")
    end
  end

  describe "POST /settings/applications" do
    let(:params) do
      { oauth_application: { name: "Intranet", redirect_uri: "https://intranet.acme.com/callback\nhttps://intranet.acme.com/other",
                             confidential: "1", backchannel_logout_uri: "", post_logout_redirect_uris: "https://intranet.acme.com/bye\n" } }
    end

    it "registers the app on this tenant and shows its secret once" do
      post settings_applications_path, params: params

      application = applications.sole
      expect(application).to have_attributes(name: "Intranet", confidential: true, backchannel_logout_uri: nil,
        redirect_uri: "https://intranet.acme.com/callback\nhttps://intranet.acme.com/other",
        post_logout_redirect_uris: [ "https://intranet.acme.com/bye" ])
      expect(response).to redirect_to(settings_application_path(application))

      follow_redirect!
      secret = response.parsed_body.at_css("#client_secret").text
      expect(application.secret_matches?(secret)).to be(true)

      get settings_application_path(application)
      expect(response.body).not_to include(secret)
    end

    it "rejects a redirect URI that isn't https" do
      params[:oauth_application][:redirect_uri] = "http://intranet.acme.com/callback"

      post settings_applications_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Redirect URIs must be https URIs")
      expect(applications).to be_empty
    end
  end

  describe "PATCH /settings/applications/:id" do
    let_it_be(:application) { create(:oauth_application, tenant:, post_logout_redirect_uris: [ "https://app.example.com/bye" ]) }

    it "keeps the secret" do
      expect { patch settings_application_path(application), params: { oauth_application: { name: "Renamed", post_logout_redirect_uris: "" } } }
        .not_to change { application.reload.secret }

      expect(response).to redirect_to(settings_application_path(application))
      expect(application).to have_attributes(name: "Renamed", post_logout_redirect_uris: [])
    end
  end

  describe "POST /settings/applications/:id/secret" do
    let_it_be(:application) { create(:oauth_application, tenant:) }

    it "replaces the secret and shows the new one once" do
      expect { post settings_application_secret_path(application) }.to change { application.reload.secret }

      follow_redirect!
      expect(application.secret_matches?(response.parsed_body.at_css("#client_secret").text)).to be(true)
    end
  end

  describe "DELETE /settings/applications/:id" do
    it "removes the app" do
      application = create(:oauth_application, tenant:)

      delete settings_application_path(application)

      expect(response).to redirect_to(settings_applications_path)
      expect(applications).to be_empty
    end

    it "can't remove a global app" do
      delete settings_application_path(create(:oauth_application))

      expect(response).to have_http_status(:not_found)
    end

    it "can't remove another tenant's app" do
      delete settings_application_path(create(:oauth_application, tenant: create(:tenant)))

      expect(response).to have_http_status(:not_found)
    end
  end
end
