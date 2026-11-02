require "rails_helper"

RSpec.describe Tenant, type: :model do
  describe "validations" do
    subject(:tenant) { build(:tenant, **attributes) }

    let(:attributes) { {} }

    it { is_expected.to be_valid }

    it "defaults the brand colors" do
      expect(tenant).to have_attributes(primary_color: "#4F46E5", secondary_color: "#0F172A")
    end

    context "without a name" do
      let(:attributes) { { name: "" } }

      it { is_expected.to be_invalid }
    end

    context "with a subdomain that has uppercase and whitespace" do
      let(:attributes) { { subdomain: "  Acme-Corp " } }

      it "normalizes it" do
        expect(tenant.subdomain).to eq("acme-corp")
      end
    end

    %w[acme_corp -acme acme- acme.corp].each do |subdomain|
      context "with the malformed subdomain #{subdomain.inspect}" do
        let(:attributes) { { subdomain: } }

        it { is_expected.to be_invalid }
      end
    end

    context "with a reserved subdomain" do
      let(:attributes) { { subdomain: "www" } }

      it "is invalid" do
        expect(tenant).to be_invalid
        expect(tenant.errors[:subdomain]).to include("is reserved")
      end
    end

    context "with a subdomain already taken" do
      let(:attributes) { { subdomain: "acme" } }

      before { create(:tenant, subdomain: "acme") }

      it { is_expected.to be_invalid }
    end

    context "with a lowercase hex color" do
      let(:attributes) { { primary_color: "#ff00aa" } }

      it "upcases it" do
        expect(tenant.primary_color).to eq("#FF00AA")
      end
    end

    %w[red #FFF #GGGGGG FF00AA].each do |color|
      context "with the invalid color #{color.inspect}" do
        let(:attributes) { { secondary_color: color } }

        it { is_expected.to be_invalid }
      end
    end

    context "with a PNG logo" do
      before { tenant.logo.attach(fixture_file_upload("logo.png", "image/png")) }

      it { is_expected.to be_valid }
    end

    context "with a non-image logo" do
      before { tenant.logo.attach(io: StringIO.new("not an image"), filename: "logo.txt", content_type: "text/plain") }

      it { is_expected.to be_invalid }
    end
  end

  describe ".find_by_host" do
    subject(:found) { described_class.find_by_host(host) }

    let!(:tenant) { create(:tenant, subdomain: "acme") }

    before do
      create(:tenant_domain, :active, tenant:, hostname: "portal.acme.com")
      create(:tenant_domain, tenant:, hostname: "pending.acme.com")
    end

    {
      "acme.localhost" => "its subdomain",
      "ACME.localhost" => "its subdomain in another case",
      "portal.acme.com" => "its active custom domain"
    }.each do |matching_host, description|
      context "with #{description}" do
        let(:host) { matching_host }

        it { is_expected.to eq(tenant) }
      end
    end

    {
      "localhost" => "the root domain",
      "www.localhost" => "the www root domain",
      "other.localhost" => "an unknown subdomain",
      "deep.acme.localhost" => "a nested subdomain",
      "pending.acme.com" => "a custom domain not yet verified",
      "acme.com" => "an unknown custom domain"
    }.each do |other_host, description|
      context "with #{description}" do
        let(:host) { other_host }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "changing the subdomain" do
    let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

    def retired_subdomains = tenant.retired_subdomains.pluck(:subdomain)

    it "keeps the old one for redirects" do
      tenant.update!(subdomain: "acme-corp")

      expect(retired_subdomains).to eq([ "acme" ])
      expect(described_class.find_by_retired_host("ACME.localhost")).to eq(tenant)
    end

    it "makes an old one current again when moving back" do
      tenant.update!(subdomain: "acme-corp")
      tenant.update!(subdomain: "acme")

      expect(retired_subdomains).to eq([ "acme-corp" ])
      expect(described_class.find_by_retired_host("acme.localhost")).to be_nil
    end

    it "reserves the old one from other tenants" do
      tenant.update!(subdomain: "acme-corp")

      other = build(:tenant, subdomain: "acme")

      expect(other).to be_invalid
      expect(other.errors[:subdomain]).to include("has already been taken")
    end

    it "leaves other changes alone" do
      tenant.update!(name: "Acme Corp")

      expect(retired_subdomains).to be_empty
    end
  end

  describe ".find_by_retired_host" do
    let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

    before_all { tenant.update!(subdomain: "acme-corp") }

    it "ignores hosts that aren't a subdomain" do
      expect(described_class.find_by_retired_host("acme.localhost.evil.com")).to be_nil
      expect(described_class.find_by_retired_host("deep.acme.localhost")).to be_nil
    end
  end

  describe "#claim_domain" do
    subject(:domain) { tenant.claim_domain(hostname) }

    let(:tenant) { create(:tenant) }

    context "with a valid hostname" do
      let(:hostname) { "portal.acme.com" }

      it "records a pending domain and syncs it with Cloudflare in the background" do
        expect(domain).to be_persisted.and be_pending
        expect(TenantDomains::SyncJob).to have_been_enqueued.with(domain)
      end
    end

    context "with an invalid hostname" do
      let(:hostname) { "not a domain" }

      it "returns the invalid domain without syncing it" do
        expect(domain).not_to be_persisted
        expect(TenantDomains::SyncJob).not_to have_been_enqueued
      end
    end
  end

  describe "default identity provider" do
    let_it_be(:tenant, refind: true) { create(:tenant) }
    let_it_be(:okta, refind: true) { create(:identity_provider, tenant:) }

    before { tenant.update!(default_identity_provider: okta) }

    context "with another tenant's provider" do
      let_it_be(:foreign) { create(:identity_provider) }

      it "isn't allowed" do
        expect(tenant.update(default_identity_provider_id: foreign.id)).to be(false)
        expect(tenant.errors[:default_identity_provider]).to be_present
      end
    end

    context "with a disabled provider" do
      let_it_be(:disabled) { create(:identity_provider, tenant:, enabled: false) }

      it "isn't allowed" do
        expect(tenant.update(default_identity_provider_id: disabled.id)).to be(false)
      end
    end

    it "is cleared when the provider is disabled" do
      ActsAsTenant.with_tenant(tenant) { okta.update!(enabled: false) }

      expect(tenant.reload.default_identity_provider_id).to be_nil
    end

    it "is cleared when the provider is deleted" do
      ActsAsTenant.with_tenant(tenant) { okta.destroy! }

      expect(tenant.reload.default_identity_provider_id).to be_nil
    end
  end

  describe "#oidc_issuer" do
    let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

    it "is the canonical host on the configured scheme and port" do
      expect(tenant.oidc_issuer(protocol: "https", root_domain: "locke.app")).to eq("https://acme.locke.app")
      expect(tenant.oidc_issuer(protocol: "http", port: 3000, root_domain: "localhost")).to eq("http://acme.localhost:3000")
    end
  end

  describe "#host" do
    it "is the subdomain under the app's root domain" do
      expect(build(:tenant, subdomain: "acme").host).to eq("acme.localhost")
    end
  end

  describe ".root_host?" do
    it "is true for the root domain and its www host only" do
      expect(described_class.root_host?("localhost")).to be(true)
      expect(described_class.root_host?("WWW.localhost")).to be(true)
      expect(described_class.root_host?("acme.localhost")).to be(false)
    end
  end
end
