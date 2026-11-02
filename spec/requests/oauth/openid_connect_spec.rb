require "rails_helper"

# Locke as an OpenID Connect provider: one issuer per tenant, codes and tokens
# that only work on the tenant they were issued on, and apps that are either
# a tenant's own or global.
RSpec.describe "OAuth: OpenID Connect", type: :request do
  let_it_be(:acme) { create(:tenant, subdomain: "acme") }
  let_it_be(:globex) { create(:tenant, subdomain: "globex") }
  let_it_be(:ada) { create(:user, tenant: acme, email: "ada@example.com") }
  let_it_be(:grace) { create(:user, tenant: globex, email: "grace@example.com") }

  let(:redirect_uri) { "https://app.example.com/callback" }
  let(:code_verifier) { SecureRandom.urlsafe_base64(48) }
  let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false) }

  let!(:mail) { ActsAsTenant.without_tenant { OauthApplication.create!(name: "Mail", redirect_uri:) } }

  before { SigningKey.generate! }

  def on(tenant) = host!("#{tenant.subdomain}.localhost")

  def authorize(client: mail, **params)
    get oauth_authorization_path, params: {
      client_id: client.uid, redirect_uri:, response_type: "code", scope: "openid email profile",
      code_challenge:, code_challenge_method: "S256", nonce: "n-0S6", state: "xyz"
    }.merge(params).compact
  end

  def code_from(response) = Rack::Utils.parse_query(URI(response.location).query)["code"]

  def exchange(code, client: mail)
    post oauth_token_path, params: {
      grant_type: "authorization_code", code:, redirect_uri:, code_verifier:,
      client_id: client.uid, client_secret: client.plaintext_secret
    }
    response.parsed_body
  end

  # Verified with the keys the tenant publishes, as an app would
  def id_token_claims(id_token)
    get "/oauth/discovery/keys"
    jwks = JWT::JWK::Set.new(response.parsed_body)
    JWT.decode(id_token, nil, true, algorithms: [ "RS256" ], jwks:).first
  end

  def sign_in_and_get_tokens(user, tenant)
    on tenant
    sign_in_as user
    authorize
    expect(response.location).to start_with(redirect_uri)
    exchange(code_from(response))
  end

  it "signs a user in and issues an ID token from the tenant's issuer" do
    tokens = sign_in_and_get_tokens(ada, acme)

    claims = id_token_claims(tokens.fetch("id_token"))
    expect(claims).to include(
      "iss" => "http://acme.localhost", "aud" => mail.uid, "sub" => ada.public_id, "nonce" => "n-0S6",
      "email" => "ada@example.com", "email_verified" => true, "amr" => [ "pwd" ]
    )
    expect(claims["auth_time"]).to be_within(5).of(Time.current.to_i)
    expect(tokens).to include("access_token", "refresh_token")
  end

  it "gives each tenant its own issuer and subjects, with one global app" do
    acme_claims = id_token_claims(sign_in_and_get_tokens(ada, acme).fetch("id_token"))
    globex_claims = id_token_claims(sign_in_and_get_tokens(grace, globex).fetch("id_token"))

    expect(globex_claims["iss"]).to eq("http://globex.localhost")
    expect(globex_claims["sub"]).to eq(grace.public_id).and(not_eq(acme_claims["sub"]))
  end

  it "doesn't redeem one tenant's code on another tenant's host" do
    on acme
    sign_in_as ada
    authorize
    code = code_from(response)

    on globex
    expect(exchange(code)).to include("error" => "invalid_grant")
  end

  it "doesn't accept one tenant's access token on another tenant's host" do
    access_token = sign_in_and_get_tokens(ada, acme).fetch("access_token")

    on globex
    get oauth_userinfo_path, headers: { "Authorization" => "Bearer #{access_token}" }
    expect(response).to have_http_status(:unauthorized)

    on acme
    get oauth_userinfo_path, headers: { "Authorization" => "Bearer #{access_token}" }
    expect(response.parsed_body).to include("sub" => ada.public_id, "email" => "ada@example.com")
  end

  it "keeps a tenant's own app to that tenant" do
    acme_app = ActsAsTenant.with_tenant(acme) { OauthApplication.create!(name: "Acme CRM", redirect_uri:) }

    on globex
    sign_in_as grace
    authorize(client: acme_app)

    expect(response.body).to include("invalid_client").or include("Client authentication failed")
    expect(response.location.to_s).not_to start_with(redirect_uri)
  end

  it "requires PKCE" do
    on acme
    sign_in_as ada
    authorize(code_challenge: nil, code_challenge_method: nil)

    expect(response.location.to_s).not_to include("code=")
  end

  it "only redirects to the registered URI" do
    on acme
    sign_in_as ada
    authorize(redirect_uri: "https://evil.example/callback")

    expect(response.location.to_s).not_to start_with("https://evil.example")
  end

  describe "signing in along the way" do
    it "sends people to sign in and back, through the 2FA challenge" do
      ActsAsTenant.with_tenant(acme) { ada.update!(otp_required_for_sign_in: true) }
      on acme
      authorize
      expect(response).to redirect_to(sign_in_path)

      sign_in_as ada
      post two_factor_authentication_challenge_totp_path, params: { code: ROTP::TOTP.new(ada.otp_secret).now }
      expect(response.location).to include("/oauth/authorize?")

      follow_redirect!
      claims = id_token_claims(exchange(code_from(response)).fetch("id_token"))
      expect(claims["amr"]).to eq(%w[pwd otp mfa])
    ensure
      ActsAsTenant.with_tenant(acme) { ada.update!(otp_required_for_sign_in: false) }
    end

    it "answers prompt=none without a session with login_required" do
      on acme
      authorize(prompt: "none")

      expect(response.location).to start_with(redirect_uri).and include("error=login_required")
    end

    it "asks a signed-in user to sign in again for prompt=login" do
      on acme
      sign_in_as ada
      authorize(prompt: "login")
      expect(response).to redirect_to(sign_in_path)

      get sign_in_path
      expect(response).to have_http_status(:ok)

      sign_in_as ada
      follow_redirect!
      expect(response.location).to start_with(redirect_uri).and include("code=")
      expect(ActsAsTenant.with_tenant(acme) { ada.sessions.count }).to eq(1)
    end

    it "asks again when the session is older than max_age" do
      on acme
      sign_in_as ada

      travel 10.minutes do
        authorize(max_age: 60)
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  it "refreshes tokens, keeping the session they came from" do
    tokens = sign_in_and_get_tokens(ada, acme)

    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens.fetch("refresh_token"), client_id: mail.uid, client_secret: mail.plaintext_secret }

    expect(response.parsed_body).to include("access_token", "id_token")
    session_ids = ActsAsTenant.with_tenant(acme) { OauthAccessToken.pluck(:session_id) }.uniq
    expect(session_ids).to eq([ ActsAsTenant.with_tenant(acme) { ada.sessions.sole.id } ])
  end

  describe "discovery" do
    it "publishes the tenant's issuer and endpoints" do
      on globex
      get "/.well-known/openid-configuration"

      expect(response.parsed_body).to include(
        "issuer" => "http://globex.localhost",
        "authorization_endpoint" => "http://globex.localhost/oauth/authorize",
        "jwks_uri" => "http://globex.localhost/oauth/discovery/keys"
      )
    end

    it "publishes every active key, so tokens signed before a rotation still verify" do
      old_token = sign_in_and_get_tokens(ada, acme).fetch("id_token")
      SigningKey.generate!

      expect(id_token_claims(old_token)["sub"]).to eq(ada.public_id)
      get "/oauth/discovery/keys"
      expect(response.parsed_body["keys"].size).to eq(2)
    end

    it "sends a tenant's other addresses to its custom domain" do
      create(:tenant_domain, :active, tenant: acme, hostname: "login.acme.com")

      on acme
      authorize
      expect(response).to redirect_to(%r{\Ahttp://login\.acme\.com/oauth/authorize\?})
    end
  end

  RSpec::Matchers.define_negated_matcher :not_eq, :eq
  include ActiveSupport::Testing::TimeHelpers
end
