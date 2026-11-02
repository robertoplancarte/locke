require "rails_helper"

RSpec.describe OauthApplication do
  describe "validations" do
    subject(:app) { build(:oauth_application, **attributes) }

    let(:attributes) { {} }

    it { is_expected.to be_valid }

    context "with a plain http back-channel logout URI outside development" do
      let(:attributes) { { backchannel_logout_uri: "http://app.example.com/logout" } }

      before { allow(Rails.env).to receive(:local?).and_return(false) }

      it { is_expected.not_to be_valid }
    end

    context "with a relative post-logout redirect URI" do
      let(:attributes) { { post_logout_redirect_uris: [ "/signed-out" ] } }

      it { is_expected.not_to be_valid }
    end

    context "with blank post-logout redirect URIs" do
      let(:attributes) { { post_logout_redirect_uris: [ " https://app.example.com/bye ", "" ] } }

      it "drops them" do
        expect(app.post_logout_redirect_uris).to eq([ "https://app.example.com/bye" ])
      end
    end
  end

  describe "#post_logout_redirect_uri?" do
    subject(:app) { build(:oauth_application, post_logout_redirect_uris: [ "https://app.example.com/bye" ]) }

    it "takes only an exact match" do
      expect(app.post_logout_redirect_uri?("https://app.example.com/bye")).to be(true)
      expect(app.post_logout_redirect_uri?("https://app.example.com/bye?next=evil")).to be(false)
      expect(app.post_logout_redirect_uri?(nil)).to be(false)
    end
  end

  describe "#log_out!" do
    let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
    let_it_be(:app) { create(:oauth_application, :backchannel_logout) }

    let(:client) { instance_double(Oauth::BackchannelLogoutClient, deliver: nil) }

    before_all { SigningKey.generate! }

    it "sends the app a logout token from the tenant's issuer" do
      app.log_out!(tenant, sub: "usr_1", sid: "ses_1", client:)

      expect(client).to have_received(:deliver) do |uri, jwt|
        expect(uri).to eq("https://app.example.com/backchannel_logout")
        expect(JWT.decode(jwt, nil, false).first).to include("iss" => "http://acme.localhost", "aud" => app.uid, "sid" => "ses_1")
      end
    end
  end
end
