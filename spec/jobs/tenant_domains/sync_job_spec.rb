require "rails_helper"

RSpec.describe TenantDomains::SyncJob, type: :job do
  let(:domain) { build_stubbed(:tenant_domain) }

  before { allow(domain).to receive(:sync!) }

  it "syncs the domain with Cloudflare" do
    described_class.new.perform(domain)

    expect(domain).to have_received(:sync!)
  end
end
