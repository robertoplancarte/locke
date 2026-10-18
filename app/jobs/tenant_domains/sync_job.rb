module TenantDomains
  class SyncJob < ApplicationJob
    # Two concurrent first syncs would both try to register the hostname
    limits_concurrency to: 1, key: ->(domain) { domain }, group: "TenantDomain"

    retry_on Cloudflare::CustomHostnames::Error, wait: :polynomially_longer, attempts: 5
    discard_on ActiveJob::DeserializationError

    def perform(domain)
      domain.sync!
      Turbo::StreamsChannel.broadcast_refresh_to(domain.tenant, :domains)
    end
  end
end
