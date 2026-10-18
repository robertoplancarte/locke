require "rails_helper"

RSpec.describe TenantDomain, type: :model do
  describe "validations" do
    subject(:domain) { build(:tenant_domain, hostname:) }

    let(:hostname) { "portal.acme.com" }

    it { is_expected.to be_valid.and be_pending }

    context "with uppercase, whitespace and a trailing dot" do
      let(:hostname) { " Portal.Acme.COM. " }

      it "normalizes the hostname" do
        expect(domain.hostname).to eq("portal.acme.com")
      end
    end

    %w[https://acme.com acme localhost acme_corp.com].each do |malformed|
      context "with the malformed hostname #{malformed.inspect}" do
        let(:hostname) { malformed }

        it { is_expected.to be_invalid }
      end
    end

    context "with a hostname under the app's root domain" do
      let(:hostname) { "acme.localhost" }

      it { is_expected.to be_invalid }
    end

    context "with a hostname claimed by another tenant" do
      before { create(:tenant_domain, hostname: "portal.acme.com") }

      it { is_expected.to be_invalid }
    end
  end

  describe "#sync!" do
    subject(:sync) { domain.sync!(client:) }

    let(:client) { instance_double(Cloudflare::CustomHostnames) }
    let(:domain) { create(:tenant_domain, hostname: "portal.acme.com") }
    let(:hostname_status) { "pending" }
    let(:ssl_status) { "pending_validation" }
    let(:custom_hostname) do
      Cloudflare::CustomHostname.new(
        id: "cf-123", hostname: "portal.acme.com", status: hostname_status, ssl_status:,
        ownership_verification: { "type" => "txt", "name" => "_cf-custom-hostname.portal.acme.com", "value" => "token" },
        verification_errors: []
      )
    end

    before do
      allow(client).to receive(:create).with("portal.acme.com").and_return(custom_hostname)
      allow(client).to receive(:find).with("cf-123").and_return(custom_hostname)
    end

    context "when not yet registered with Cloudflare" do
      it "registers it and records the verification details" do
        sync

        expect(client).to have_received(:create)
        expect(domain).to be_pending
        expect(domain).to have_attributes(
          cloudflare_id: "cf-123", hostname_status: "pending", ssl_status: "pending_validation",
          verified_at: nil, last_checked_at: be_present
        )
        expect(domain.ownership_verification).to include("name" => "_cf-custom-hostname.portal.acme.com")
      end
    end

    context "when Cloudflare rejects the hostname" do
      before do
        allow(client).to receive(:create).and_raise(Cloudflare::CustomHostnames::Rejected.new([ "Duplicate custom hostname found." ]))
      end

      it "marks it failed with Cloudflare's reason" do
        sync

        expect(domain).to be_failed
        expect(domain.verification_errors).to eq([ "Duplicate custom hostname found." ])
      end
    end

    context "when registered and Cloudflare has verified it and issued the certificate" do
      let(:domain) { create(:tenant_domain, hostname: "portal.acme.com", cloudflare_id: "cf-123") }
      let(:hostname_status) { "active" }
      let(:ssl_status) { "active" }

      it "activates it" do
        sync

        expect(client).to have_received(:find)
        expect(domain).to be_active
        expect(domain.verified_at).to be_present
      end
    end

    context "when verified but Cloudflare hasn't issued the certificate yet" do
      let(:domain) { create(:tenant_domain, hostname: "portal.acme.com", cloudflare_id: "cf-123") }
      let(:hostname_status) { "active" }

      it { expect { sync }.not_to change(domain, :status).from("pending") }
    end

    context "when Cloudflare blocks the hostname" do
      let(:domain) { create(:tenant_domain, hostname: "portal.acme.com", cloudflare_id: "cf-123") }
      let(:hostname_status) { "blocked" }

      it { expect { sync }.to change(domain, :status).to("failed") }
    end

    context "when an active domain's certificate is renewing" do
      let(:domain) { create(:tenant_domain, :active, hostname: "portal.acme.com", cloudflare_id: "cf-123") }
      let(:hostname_status) { "active" }

      it "keeps serving it" do
        expect { sync }.not_to change(domain, :status).from("active")
      end
    end

    context "when an active domain stops pointing at Cloudflare" do
      let(:domain) { create(:tenant_domain, :active, hostname: "portal.acme.com", cloudflare_id: "cf-123") }
      let(:hostname_status) { "moved" }

      it { expect { sync }.to change(domain, :status).from("active").to("inactive") }
    end

    context "when the custom hostname was deleted in Cloudflare" do
      let(:domain) { create(:tenant_domain, :active, hostname: "portal.acme.com", cloudflare_id: "cf-123") }

      before { allow(client).to receive(:find).with("cf-123").and_return(nil) }

      it "stops serving it and forgets the Cloudflare id so the next sync registers it again" do
        sync

        expect(domain).to be_inactive
        expect(domain.cloudflare_id).to be_nil
      end
    end
  end

  describe "#release!" do
    let(:client) { instance_double(Cloudflare::CustomHostnames, delete: nil) }
    let!(:domain) { create(:tenant_domain, cloudflare_id: "cf-123") }

    it "removes it from Cloudflare and deletes it" do
      expect { domain.release!(client:) }.to change(described_class, :count).by(-1)
      expect(client).to have_received(:delete).with("cf-123")
    end
  end

  describe "#dns_records" do
    subject(:records) { domain.dns_records }

    let(:domain) { build(:tenant_domain, hostname: "portal.acme.com", ownership_verification:) }

    context "before Cloudflare has issued an ownership token" do
      let(:ownership_verification) { {} }

      it "asks only for the CNAME" do
        expect(records).to eq([ { type: "CNAME", name: "portal.acme.com", value: "tenants.localhost" } ])
      end
    end

    context "with an ownership token" do
      let(:ownership_verification) { { "type" => "txt", "name" => "_cf-custom-hostname.portal.acme.com", "value" => "token" } }

      it "also offers the TXT record for verifying before switching traffic" do
        expect(records).to include({ type: "TXT", name: "_cf-custom-hostname.portal.acme.com", value: "token" })
      end
    end
  end

  describe "scopes" do
    let_it_be(:fresh_pending) { create(:tenant_domain) }
    let_it_be(:stale_pending) { create(:tenant_domain, created_at: 8.days.ago) }
    let_it_be(:recently_checked) { create(:tenant_domain, :active, last_checked_at: 1.hour.ago) }
    let_it_be(:due_active) { create(:tenant_domain, :active, last_checked_at: 2.days.ago) }
    let_it_be(:due_inactive) { create(:tenant_domain, :active, status: "inactive", last_checked_at: nil) }

    it ".stale_pending finds claims older than the TTL" do
      expect(described_class.stale_pending).to contain_exactly(stale_pending)
    end

    it ".due_for_recheck finds verified domains not checked recently" do
      expect(described_class.due_for_recheck).to contain_exactly(due_active, due_inactive)
    end
  end
end
