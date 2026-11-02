require "rails_helper"

# Logging out across apps. Which hints, apps and redirect addresses count is
# covered in spec/models/end_session_request_spec.rb, and what ending a session
# does to tokens and apps in spec/models/session_spec.rb.
RSpec.describe "OAuth: logging out", type: :request do
  let_it_be(:acme) { create(:tenant, subdomain: "acme") }
  let_it_be(:ada) { create(:user, tenant: acme, email: "ada@example.com") }
  let_it_be(:mail) do
    create(:oauth_application, :backchannel_logout, redirect_uri:, post_logout_redirect_uris: [ "https://app.example.com/bye" ])
  end

  let(:code_verifier) { SecureRandom.urlsafe_base64(48) }

  before_all { SigningKey.generate! }

  before { host! "acme.localhost" }

  def self.redirect_uri = "https://app.example.com/callback"
  delegate :redirect_uri, to: :class

  def ada_session = ActsAsTenant.with_tenant(acme) { ada.sessions.sole }

  # Signs in to the app as it would: authorization code with PKCE
  def sign_in_to_app
    sign_in_as ada
    get oauth_authorization_path, params: {
      client_id: mail.uid, redirect_uri:, response_type: "code", scope: "openid",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false), code_challenge_method: "S256"
    }
    code = Rack::Utils.parse_query(URI(response.location).query)["code"]
    post oauth_token_path, params: {
      grant_type: "authorization_code", code:, redirect_uri:, code_verifier:, client_id: mail.uid, client_secret: mail.plaintext_secret
    }
    response.parsed_body
  end

  describe "from an app, with its ID token" do
    let!(:tokens) { sign_in_to_app }

    it "logs out of Locke, tells the apps, and goes back to the app" do
      session_record = ada_session

      expect {
        get oauth_logout_path, params: { id_token_hint: tokens.fetch("id_token"), post_logout_redirect_uri: "https://app.example.com/bye", state: "xyz" }
      }.to have_enqueued_job(Oauth::BackchannelLogoutJob).with(acme, mail.id, sub: ada.public_id, sid: session_record.sid)

      expect(response).to redirect_to("https://app.example.com/bye?state=xyz")
      expect(ada.sessions).to be_empty
      get root_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "takes a POST from the app's page, without the session cookie or a CSRF token" do
      cookies.delete(:session_token)

      post oauth_logout_path, params: { id_token_hint: tokens.fetch("id_token") }

      expect(response).to redirect_to(sign_in_path)
      expect(ada.sessions).to be_empty
    end

    it "stops the refresh token working" do
      get oauth_logout_path, params: { id_token_hint: tokens.fetch("id_token") }

      post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens.fetch("refresh_token"), client_id: mail.uid, client_secret: mail.plaintext_secret }
      expect(response.parsed_body).to include("error" => "invalid_grant")
    end
  end

  describe "without an ID token" do
    before { sign_in_as ada }

    it "asks first, then logs out" do
      get oauth_logout_path, params: { client_id: mail.uid, post_logout_redirect_uri: "https://app.example.com/bye" }

      expect(response.body).to include("Log out of").and include("#{mail.name} asked")
      expect(ada.sessions).to exist

      delete oauth_logout_path, params: { client_id: mail.uid, post_logout_redirect_uri: "https://app.example.com/bye" }

      expect(response).to redirect_to("https://app.example.com/bye")
      expect(ada.sessions).to be_empty
    end
  end

  describe "when already logged out" do
    it "says so" do
      get oauth_logout_path

      expect(response).to redirect_to(sign_in_path)
      expect(flash[:notice]).to eq("You're logged out")
    end
  end

  describe "from Locke's own sessions page" do
    let!(:tokens) { sign_in_to_app }

    it "tells the apps too" do
      expect { delete session_path(ada_session) }.to have_enqueued_job(Oauth::BackchannelLogoutJob)
    end
  end
end
