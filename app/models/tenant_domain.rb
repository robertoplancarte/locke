# A tenant's custom domain. Cloudflare for SaaS proves the tenant controls it
# and issues its TLS certificate; requests are only routed to active domains.
#
# Lifecycle: pending (claimed, waiting for DNS) -> active (verified, serving)
# -> inactive (stopped pointing at us after being verified). Cloudflare
# rejecting the hostname outright leaves it failed. Removing a domain marks it
# releasing, which stops routing at once, until Cloudflare has deleted it.
class TenantDomain < ApplicationRecord
  HOSTNAME_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/
  # Unverified claims are released so they can't squat a hostname indefinitely
  PENDING_TTL = 7.days
  RECHECK_INTERVAL = 1.day
  # A release still pending after this is assumed to have exhausted its retries
  RELEASE_TIMEOUT = 1.hour

  belongs_to :tenant

  enum :status, %w[pending active inactive failed releasing].index_by(&:itself), default: :pending, validate: true

  normalizes :hostname, with: ->(value) { value.strip.downcase.delete_suffix(".") }

  validates :hostname, presence: true, uniqueness: true, format: { with: HOSTNAME_FORMAT }
  validate :hostname_outside_root_domain

  scope :stale_pending, -> { pending.where(created_at: ...PENDING_TTL.ago) }
  scope :due_for_recheck, -> { where(status: %w[active inactive]).where(last_checked_at: [ nil, ...RECHECK_INTERVAL.ago ]) }
  scope :stuck_releasing, -> { releasing.where(updated_at: ...RELEASE_TIMEOUT.ago) }

  def sync_later
    TenantDomains::SyncJob.perform_later(self)
  end

  # Registers the hostname with Cloudflare on first sync, then mirrors its
  # verification and certificate state.
  def sync!(client: Cloudflare::CustomHostnames.new)
    return if releasing?

    custom_hostname = cloudflare_id ? client.find(cloudflare_id) : client.create(hostname)
    return mark_missing_from_cloudflare if custom_hostname.nil?

    apply(custom_hostname)
  rescue Cloudflare::CustomHostnames::Rejected => error
    # A 404 here means the zone itself is misconfigured, not that the hostname is bad
    raise if error.is_a?(Cloudflare::CustomHostnames::NotFound)

    update!(status: :failed, verification_errors: error.messages, last_checked_at: Time.current)
  end

  def release_later
    update!(status: :releasing)
    TenantDomains::ReleaseJob.perform_later(self)
  end

  def release!(client: Cloudflare::CustomHostnames.new)
    client.delete(cloudflare_id) if cloudflare_id
    destroy!
  end

  # The records the tenant adds at their DNS provider. The CNAME routes traffic
  # (and is all Cloudflare needs); the TXT record lets them verify ownership
  # before switching traffic over.
  def dns_records
    records = [ { type: "CNAME", name: hostname, value: Rails.configuration.x.cloudflare.cname_target } ]
    if ownership_verification.present?
      records << { type: "TXT", name: ownership_verification["name"], value: ownership_verification["value"] }
    end
    records
  end

  private

  def apply(custom_hostname)
    status = status_for(custom_hostname)
    update!(
      status:,
      cloudflare_id: custom_hostname.id,
      hostname_status: custom_hostname.status,
      ssl_status: custom_hostname.ssl_status,
      ownership_verification: custom_hostname.ownership_verification,
      verification_errors: custom_hostname.verification_errors,
      verified_at: verified_at || (Time.current if status == :active),
      last_checked_at: Time.current
    )
  end

  # A verified domain stays active while its certificate renews; it only goes
  # inactive once Cloudflare stops seeing traffic for it (e.g. DNS changed).
  def status_for(custom_hostname)
    if custom_hostname.active? && (custom_hostname.ssl_active? || verified_at?)
      :active
    elsif verified_at?
      :inactive
    elsif custom_hostname.blocked?
      :failed
    else
      :pending
    end
  end

  # Deleted on Cloudflare's side; the next sync registers it again.
  def mark_missing_from_cloudflare
    update!(cloudflare_id: nil, status: verified_at? ? :inactive : :pending, last_checked_at: Time.current)
  end

  def hostname_outside_root_domain
    root_domain = Rails.configuration.x.root_domain
    return unless hostname == root_domain || hostname&.end_with?(".#{root_domain}")

    errors.add(:hostname, "can't be on #{root_domain}; use the subdomain instead")
  end
end
