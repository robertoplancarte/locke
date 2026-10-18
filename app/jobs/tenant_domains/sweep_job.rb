module TenantDomains
  # Polls Cloudflare for domains waiting on DNS, re-checks verified ones so a
  # domain that stops pointing at us stops being served, releases claims that
  # were never verified, and retries removals that didn't complete.
  class SweepJob < ApplicationJob
    def perform
      TenantDomain.stale_pending.find_each(&:release_later)
      TenantDomain.stuck_releasing.find_each { |domain| ReleaseJob.perform_later(domain) }
      TenantDomain.pending.where(created_at: TenantDomain::PENDING_TTL.ago..).find_each { |domain| SyncJob.perform_later(domain) }
      TenantDomain.due_for_recheck.find_each { |domain| SyncJob.perform_later(domain) }
    end
  end
end
