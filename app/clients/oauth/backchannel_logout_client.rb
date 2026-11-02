require "net/http"

module Oauth
  # Posts logout tokens to apps' backchannel_logout_uri.
  # https://openid.net/specs/openid-connect-backchannel-1_0.html#BCRequest
  class BackchannelLogoutClient
    # The app couldn't be reached or failed; safe to retry.
    class Error < StandardError; end

    # The app refused the token (a 4xx); retrying won't help.
    class Rejected < Error; end

    def deliver(uri, logout_token)
      uri = URI(uri)
      request = Net::HTTP::Post.new(uri, "Cache-Control" => "no-store")
      request.set_form_data(logout_token:)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      case response
      when Net::HTTPSuccess then nil
      when Net::HTTPClientError then raise Rejected, "#{uri} refused the logout token (#{response.code})"
      else raise Error, "#{uri} responded #{response.code}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error, "Logout request to #{uri} failed: #{error.message}"
    end
  end
end
