require "rails_helper"

RSpec.describe "User management", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }
  let_it_be(:identity_provider) { create(:identity_provider, tenant:, name: "Keycloak") }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  describe "GET /user_management" do
    before_all do
      create(:user, tenant:, managed_by: identity_provider)
      create(:user, tenant:, deactivated_at: Time.current)
      ActsAsTenant.with_tenant(tenant) do
        ProvisioningIssue.report(identity_provider:, source: :scim, message: "Keycloak couldn't update bob@example.com: Email has already been taken")
        ProvisioningIssue.report(identity_provider:, source: :scim, message: "An old problem").resolve
      end
    end

    it "counts the users and lists the unresolved issues" do
      get user_management_root_path

      counts = response.parsed_body.css("dl > div").to_h { [ it.at_css("dt").text.strip, it.at_css("dd").text.strip ] }
      expect(counts).to eq("Active users" => "2", "Signed in in the last 30 days" => "1", "Deactivated" => "1")
      expect(response.body).to include("Keycloak couldn&#39;t update bob@example.com").and include("1 user")
      expect(response.body).not_to include("An old problem")
    end
  end

  describe "POST /user_management/issues/:id/resolution" do
    let(:issue) { ActsAsTenant.with_tenant(tenant) { ProvisioningIssue.report(identity_provider:, source: :sign_in, message: "Couldn't update") } }

    it "resolves the issue" do
      post user_management_issue_resolution_path(issue)

      expect(response).to redirect_to(user_management_root_path)
      expect(issue.reload.resolved_at).to be_present
    end
  end
end
