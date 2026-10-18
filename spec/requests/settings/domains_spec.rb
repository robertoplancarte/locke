require "rails_helper"

RSpec.describe "Settings: domains", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

  before { host! "acme.localhost" }

  describe "GET /settings/domains" do
    let_it_be(:domain) do
      create(:tenant_domain, tenant:, hostname: "portal.acme.com",
        ownership_verification: { "name" => "_cf-custom-hostname.portal.acme.com", "value" => "token-value" })
    end
    let_it_be(:other_tenants_domain) { create(:tenant_domain, hostname: "portal.other.com") }

    it "lists the tenant's domains with their DNS instructions" do
      get settings_domains_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("portal.acme.com", "Waiting for DNS", "tenants.localhost", "token-value")
      expect(response.body).not_to include("portal.other.com")
    end
  end

  describe "POST /settings/domains" do
    subject(:add_domain) { post settings_domains_path, params: { tenant_domain: { hostname: } } }

    context "with a valid hostname" do
      let(:hostname) { "portal.acme.com" }

      it "claims it for the tenant" do
        expect { add_domain }.to change { tenant.domains.count }.by(1)
        expect(response).to redirect_to(settings_domains_path)
        expect(TenantDomains::SyncJob).to have_been_enqueued
      end
    end

    context "with an invalid hostname" do
      let(:hostname) { "not a domain" }

      it "shows the errors" do
        add_domain

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Hostname is invalid")
      end
    end
  end

  describe "DELETE /settings/domains/:id" do
    let!(:domain) { create(:tenant_domain, :active, tenant:) }

    it "stops serving it and releases it in the background" do
      delete settings_domain_path(domain)

      expect(response).to redirect_to(settings_domains_path)
      expect(domain.reload).to be_releasing
      expect(TenantDomains::ReleaseJob).to have_been_enqueued.with(domain)
    end

    it "can't remove another tenant's domain" do
      other_domain = create(:tenant_domain)
      delete settings_domain_path(other_domain)

      expect(response).to have_http_status(:not_found)
      expect(other_domain.reload).to be_pending
    end
  end

  describe "POST /settings/domains/:domain_id/check" do
    let!(:domain) { create(:tenant_domain, tenant:) }

    it "re-checks it in the background" do
      post settings_domain_check_path(domain)

      expect(response).to redirect_to(settings_domains_path)
      expect(TenantDomains::SyncJob).to have_been_enqueued.with(domain)
    end
  end
end
