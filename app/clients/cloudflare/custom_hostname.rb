module Cloudflare
  # A Cloudflare for SaaS custom hostname, as returned by the API.
  CustomHostname = Data.define(:id, :hostname, :status, :ssl_status, :ownership_verification, :verification_errors) do
    def self.from_api(result)
      new(
        id: result.fetch("id"),
        hostname: result.fetch("hostname"),
        status: result["status"],
        ssl_status: result.dig("ssl", "status"),
        ownership_verification: result["ownership_verification"].to_h.slice("type", "name", "value"),
        verification_errors: [ *result["verification_errors"], *result.dig("ssl", "validation_errors")&.pluck("message") ]
      )
    end

    def active? = status == "active"
    def ssl_active? = ssl_status == "active"
    def blocked? = status.in?(%w[blocked pending_blocked])
  end
end
