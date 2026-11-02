require "rails_helper"

RSpec.describe EndSessionRequest do
  subject(:end_session) { described_class.new(issuer:, **params) }

  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:user) { create(:user, tenant:) }
  let_it_be(:session) { create(:session, user:) }
  let_it_be(:app) { create(:oauth_application, post_logout_redirect_uris: [ "https://app.example.com/bye" ]) }

  let(:issuer) { "http://acme.localhost" }
  let(:claims) { { iss: issuer, aud: app.uid, sub: user.public_id, sid: session.sid, exp: 1.hour.ago.to_i } }
  let(:params) { { id_token_hint: id_token(claims) } }

  before_all { SigningKey.generate! }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  def id_token(claims, key: Doorkeeper::OpenidConnect.signing_key)
    JWT.encode(claims, key.signing_key, "RS256", { kid: key.kid })
  end

  describe "#hinted_session" do
    it "is the session an ID token from this issuer names, even long expired" do
      expect(end_session.hinted_session).to eq(session)
    end

    context "with another issuer's ID token" do
      let(:claims) { super().merge(iss: "http://globex.localhost") }

      it { expect(end_session.hinted_session).to be_nil }
    end

    context "with an ID token signed by another key" do
      let(:params) { { id_token_hint: id_token(claims, key: JWT::JWK.new(OpenSSL::PKey::RSA.new(2048))) } }

      it { expect(end_session.hinted_session).to be_nil }
    end

    context "with a logout token" do
      let(:claims) { super().merge(events: { LogoutToken::EVENT => {} }) }

      it { expect(end_session.hinted_session).to be_nil }
    end

    context "with another user's subject" do
      let(:claims) { super().merge(sub: create(:user, tenant:).public_id) }

      it { expect(end_session.hinted_session).to be_nil }
    end

    context "with junk" do
      let(:params) { { id_token_hint: "not-a-jwt" } }

      it { expect(end_session.hinted_session).to be_nil }
    end
  end

  describe "#redirect_uri" do
    let(:params) { super().merge(post_logout_redirect_uri: "https://app.example.com/bye", state: "xyz") }

    it "is the app's registered address, with the state handed back" do
      expect(end_session.redirect_uri).to eq("https://app.example.com/bye?state=xyz")
    end

    context "with an address the app didn't register" do
      let(:params) { super().merge(post_logout_redirect_uri: "https://evil.example.com/") }

      it { expect(end_session.redirect_uri).to be_nil }
    end

    context "with client_id instead of a hint" do
      let(:params) { { client_id: app.uid, post_logout_redirect_uri: "https://app.example.com/bye" } }

      it { expect(end_session.redirect_uri).to eq("https://app.example.com/bye") }
    end

    context "when client_id and the hint name different apps" do
      let(:params) { super().merge(client_id: create(:oauth_application).uid) }

      it { expect(end_session.redirect_uri).to be_nil }
    end

    context "without saying which app is asking" do
      let(:params) { { post_logout_redirect_uri: "https://app.example.com/bye" } }

      it { expect(end_session.redirect_uri).to be_nil }
    end
  end
end
