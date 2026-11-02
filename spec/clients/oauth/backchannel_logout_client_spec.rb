require "rails_helper"

RSpec.describe Oauth::BackchannelLogoutClient do
  subject(:deliver) { described_class.new.deliver(uri, "the.logout.token") }

  let(:uri) { "https://app.example.com/backchannel_logout" }

  it "posts the logout token as a form" do
    request = stub_request(:post, uri).with(body: { logout_token: "the.logout.token" }).to_return(status: 200)

    deliver

    expect(request).to have_been_requested
  end

  it "takes a 204 as done" do
    stub_request(:post, uri).to_return(status: 204)

    expect(deliver).to be_nil
  end

  it "says when the app refused it, so it isn't retried" do
    stub_request(:post, uri).to_return(status: 400)

    expect { deliver }.to raise_error(described_class::Rejected)
  end

  it "says when the app failed, so it's retried" do
    stub_request(:post, uri).to_return(status: 503)

    expect { deliver }.to raise_error(described_class::Error) { |error| expect(error).not_to be_a(described_class::Rejected) }
  end

  it "says when the app can't be reached" do
    stub_request(:post, uri).to_timeout

    expect { deliver }.to raise_error(described_class::Error)
  end
end
