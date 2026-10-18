require "net/http"

module Cloudflare
  # Client for the Cloudflare for SaaS custom hostnames API, which verifies
  # ownership of tenant domains and issues their TLS certificates.
  # https://developers.cloudflare.com/api/resources/custom_hostnames/
  class CustomHostnames
    # Cloudflare couldn't be reached or failed; safe to retry.
    class Error < StandardError; end

    # Cloudflare refused the request (e.g. duplicate or invalid hostname); retrying won't help.
    class Rejected < Error
      attr_reader :messages

      def initialize(messages)
        @messages = messages
        super(messages.join(", "))
      end
    end

    class NotFound < Rejected; end

    BASE_URL = "https://api.cloudflare.com/client/v4"

    def initialize(api_token: config.api_token, zone_id: config.zone_id)
      @api_token = api_token.presence or raise Error, "Cloudflare API token is not configured (CLOUDFLARE_API_TOKEN)"
      @zone_id = zone_id.presence or raise Error, "Cloudflare zone is not configured (CLOUDFLARE_ZONE_ID)"
    end

    # HTTP validation lets Cloudflare verify ownership and issue the certificate
    # as soon as the hostname's CNAME points at the zone's fallback origin.
    def create(hostname)
      CustomHostname.from_api(request(Net::HTTP::Post, body: { hostname:, ssl: { method: "http", type: "dv" } }))
    end

    # Returns nil when the custom hostname no longer exists in Cloudflare.
    def find(id)
      CustomHostname.from_api(request(Net::HTTP::Get, id:))
    rescue NotFound
      nil
    end

    def delete(id)
      request(Net::HTTP::Delete, id:)
      nil
    rescue NotFound
      nil
    end

    private

    def config = Rails.configuration.x.cloudflare

    def request(verb, id: nil, body: nil)
      uri = URI("#{BASE_URL}/zones/#{@zone_id}/custom_hostnames#{"/#{id}" if id}")
      http_request = verb.new(uri, "Authorization" => "Bearer #{@api_token}", "Content-Type" => "application/json")
      http_request.body = body.to_json if body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.request(http_request)
      end
      parse(response)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error, "Cloudflare request failed: #{error.message}"
    end

    def parse(response)
      raise Error, "Cloudflare responded #{response.code}" if response.is_a?(Net::HTTPServerError)

      payload = JSON.parse(response.body)
      return payload["result"] if payload["success"]

      messages = payload["errors"].to_a.pluck("message")
      raise(response.is_a?(Net::HTTPNotFound) ? NotFound.new(messages) : Rejected.new(messages))
    rescue JSON::ParserError
      raise Error, "Cloudflare responded #{response.code} with an unreadable body"
    end
  end
end
