require "rails_helper"

RSpec.describe Cloudflare::CustomHostnames do
  subject(:client) { described_class.new(api_token: "token", zone_id: "zone") }

  let(:endpoint) { "https://api.cloudflare.com/client/v4/zones/zone/custom_hostnames" }
  let(:result) do
    {
      "id" => "cf-123",
      "hostname" => "portal.acme.com",
      "status" => "pending",
      "ssl" => { "status" => "pending_validation", "validation_errors" => [ { "message" => "CAA record blocks issuance" } ] },
      "ownership_verification" => { "type" => "txt", "name" => "_cf-custom-hostname.portal.acme.com", "value" => "token-value" },
      "verification_errors" => [ "custom hostname does not CNAME to this zone." ]
    }
  end

  def respond_with(status, body)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  describe "#create" do
    it "registers the hostname for HTTP validation and returns its state" do
      request = stub_request(:post, endpoint)
        .with(
          headers: { "Authorization" => "Bearer token" },
          body: { hostname: "portal.acme.com", ssl: { method: "http", type: "dv" } }
        )
        .to_return(respond_with(200, success: true, result:))

      expect(client.create("portal.acme.com")).to have_attributes(
        id: "cf-123",
        status: "pending",
        ssl_status: "pending_validation",
        ownership_verification: { "type" => "txt", "name" => "_cf-custom-hostname.portal.acme.com", "value" => "token-value" },
        verification_errors: [ "custom hostname does not CNAME to this zone.", "CAA record blocks issuance" ]
      )
      expect(request).to have_been_requested
    end

    it "raises Rejected with Cloudflare's messages when refused" do
      stub_request(:post, endpoint)
        .to_return(respond_with(409, success: false, errors: [ { code: 1406, message: "Duplicate custom hostname found." } ]))

      expect { client.create("portal.acme.com") }.to raise_error(described_class::Rejected) { |error|
        expect(error.messages).to eq([ "Duplicate custom hostname found." ])
      }
    end

    it "raises a retryable Error when Cloudflare is down" do
      stub_request(:post, endpoint).to_return(status: 502, body: "<html>Bad gateway</html>")

      expect { client.create("portal.acme.com") }.to raise_error(described_class::Error) { |error|
        expect(error).not_to be_a(described_class::Rejected)
      }
    end

    it "raises a retryable Error on timeouts" do
      stub_request(:post, endpoint).to_timeout

      expect { client.create("portal.acme.com") }.to raise_error(described_class::Error, /request failed/)
    end
  end

  describe "#find" do
    it "returns the hostname's state" do
      stub_request(:get, "#{endpoint}/cf-123").to_return(respond_with(200, success: true, result:))

      expect(client.find("cf-123")).to have_attributes(id: "cf-123", status: "pending")
    end

    it "returns nil when it no longer exists" do
      stub_request(:get, "#{endpoint}/cf-123")
        .to_return(respond_with(404, success: false, errors: [ { code: 1436, message: "Custom hostname not found." } ]))

      expect(client.find("cf-123")).to be_nil
    end
  end

  describe "#delete" do
    it "deletes the hostname, tolerating one that's already gone" do
      request = stub_request(:delete, "#{endpoint}/cf-123")
        .to_return(respond_with(404, success: false, errors: [ { message: "Custom hostname not found." } ]))

      expect(client.delete("cf-123")).to be_nil
      expect(request).to have_been_requested
    end
  end

  it "refuses to build without credentials" do
    expect { described_class.new(api_token: nil, zone_id: "zone") }.to raise_error(described_class::Error, /CLOUDFLARE_API_TOKEN/)
  end
end
