require "rails_helper"

# The SCIM API's HTTP side: authentication, the SCIM JSON going in and out, and
# status codes. What provisioning does is covered in spec/models/user_provisioning_spec.rb.
RSpec.describe "SCIM: users", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:identity_provider, refind: true) { create(:identity_provider, tenant:, name: "Keycloak") }
  let_it_be(:ada, refind: true) { create(:user, tenant:, email: "ada@example.com") }

  let(:token) { identity_provider.generate_scim_token }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/scim+json" } }

  before { host! "acme.localhost" }

  def scim(method, path, body = nil) = public_send(method, path, params: body&.to_json, headers:)
  # Rails only parses the JSON media types it knows, and SCIM's isn't one of them
  def json = JSON.parse(response.body)

  describe "authentication" do
    it "refuses requests without the provider's token" do
      get scim_users_path, headers: { "Authorization" => "Bearer nope" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq("application/scim+json")
      expect(json).to include("schemas" => [ Scim::ERROR_SCHEMA ], "status" => "401")
    end

    it "refuses a token from another tenant's provider" do
      other_token = create(:identity_provider).generate_scim_token

      get scim_users_path, headers: { "Authorization" => "Bearer #{other_token}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /scim/v2/Users" do
    it "finds a user by userName, as a list response" do
      scim :get, scim_users_path(filter: 'userName eq "ada@example.com"')

      expect(json).to include("schemas" => [ Scim::LIST_SCHEMA ], "totalResults" => 1)
      expect(json["Resources"].sole).to include("id" => ada.public_id, "userName" => "ada@example.com", "active" => true)
    end

    it "answers an unsupported filter with a 400" do
      scim :get, scim_users_path(filter: 'userName co "ada"')

      expect(response).to have_http_status(:bad_request)
      expect(json).to include("scimType" => "invalidFilter")
    end
  end

  describe "POST /scim/v2/Users" do
    it "adds the user, managed by the provider" do
      scim :post, scim_users_path, { schemas: [ Scim::USER_SCHEMA ], userName: "grace@example.com", externalId: "kc-2",
        name: { givenName: "Grace", familyName: "Hopper" }, emails: [ { value: "grace@example.com", primary: true } ], active: true }

      expect(response).to have_http_status(:created)
      grace = ActsAsTenant.with_tenant(tenant) { User.find_by!(email: "grace@example.com") }
      expect(response.headers["Location"]).to eq(scim_user_url(grace.public_id))
      expect(json).to include("id" => grace.public_id, "externalId" => "kc-2", "displayName" => "Grace Hopper")
      expect(grace.managed_by_id).to eq(identity_provider.id)
    end
  end

  describe "PATCH /scim/v2/Users/:id" do
    it "applies the operations and answers with the user" do
      scim :patch, scim_user_path(ada.public_id), { schemas: [ "urn:ietf:params:scim:api:messages:2.0:PatchOp" ],
        Operations: [ { op: "replace", path: "active", value: false } ] }

      expect(response).to have_http_status(:ok)
      expect(json).to include("active" => false)
      expect(ada.reload).not_to be_active
    end

    it "answers a taken email with a 409" do
      create(:user, tenant:, email: "taken@example.com")

      scim :patch, scim_user_path(ada.public_id), { Operations: [ { op: "replace", path: "userName", value: "taken@example.com" } ] }

      expect(response).to have_http_status(:conflict)
      expect(json).to include("scimType" => "uniqueness", "detail" => "Email has already been taken")
    end

    it "answers a user another provider manages with a 403" do
      okta = create(:identity_provider, tenant:, name: "Okta")
      ActsAsTenant.with_tenant(tenant) { ada.update!(managed_by: okta) }

      scim :patch, scim_user_path(ada.public_id), { Operations: [ { op: "replace", path: "active", value: false } ] }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /scim/v2/Users/:id" do
    it "replaces the user's attributes" do
      scim :put, scim_user_path(ada.public_id), { userName: "ada@example.com", name: { formatted: "Ada King" }, active: true }

      expect(response).to have_http_status(:ok)
      expect(ada.reload.name).to eq("Ada King")
    end
  end

  describe "DELETE /scim/v2/Users/:id" do
    it "deactivates the user rather than deleting them" do
      scim :delete, scim_user_path(ada.public_id)

      expect(response).to have_http_status(:no_content)
      expect(ada.reload).not_to be_active
    end
  end

  it "answers an unknown user with a SCIM 404" do
    scim :get, scim_user_path("usr_unknown")

    expect(response).to have_http_status(:not_found)
    expect(json).to include("schemas" => [ Scim::ERROR_SCHEMA ])
  end

  it "describes what it supports" do
    scim :get, scim_service_provider_config_path

    expect(json).to include("patch" => { "supported" => true }, "bulk" => include("supported" => false))
  end
end
