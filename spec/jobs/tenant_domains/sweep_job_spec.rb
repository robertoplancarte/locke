require "rails_helper"

RSpec.describe TenantDomains::SweepJob, type: :job do
  subject(:perform) { described_class.new.perform }

  let!(:fresh_pending) { create(:tenant_domain) }
  let!(:stale_pending) { create(:tenant_domain, created_at: 8.days.ago) }
  let!(:due_active) { create(:tenant_domain, :active, last_checked_at: 2.days.ago) }

  before { create(:tenant_domain, :active, last_checked_at: 1.hour.ago) }

  it "syncs pending and due domains and releases stale claims" do
    perform

    expect(TenantDomains::SyncJob).to have_been_enqueued.with(fresh_pending)
    expect(TenantDomains::SyncJob).to have_been_enqueued.with(due_active)
    expect(TenantDomains::ReleaseJob).to have_been_enqueued.with(stale_pending)
    expect(enqueued_jobs.size).to eq(3)
  end
end
