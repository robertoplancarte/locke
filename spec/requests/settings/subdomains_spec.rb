require "rails_helper"

# Subdomain rules (format, reserved names, uniqueness) are covered in tenant_spec.rb
RSpec.describe "Settings: subdomain", type: :request do
  subject(:update_subdomain) { patch settings_subdomain_path, params: { tenant: { subdomain: } } }

  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user) { create(:user, tenant:) }

  let(:subdomain) { "Acme-Corp" }
  let(:host) { "acme.localhost" }

  before do
    host! host
    sign_in_as user
  end

  it "moves the workspace and sends the user to sign in at the new address" do
    update_subdomain

    expect(tenant.reload.subdomain).to eq("acme-corp")
    expect(response).to redirect_to("http://acme-corp.localhost/sign_in")
  end

  it "redirects the old address to the new one, keeping the path and query" do
    update_subdomain

    get edit_identity_password_reset_path(sid: "token")

    expect(response).to redirect_to("http://acme-corp.localhost/identity/password_reset/edit?sid=token")
  end

  context "from a custom domain" do
    let_it_be(:domain) { create(:tenant_domain, :active, tenant:, hostname: "portal.acme.com") }

    let(:host) { "portal.acme.com" }

    it "stays on the custom domain, which keeps working" do
      update_subdomain

      expect(response).to redirect_to(settings_domains_path)
      expect(tenant.reload.subdomain).to eq("acme-corp")
    end
  end

  context "with a subdomain that's taken" do
    let_it_be(:other_tenant) { create(:tenant, subdomain: "taken") }

    let(:subdomain) { "taken" }

    it "keeps the current address" do
      update_subdomain

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Subdomain has already been taken")
      expect(tenant.reload.subdomain).to eq("acme")
    end
  end
end
