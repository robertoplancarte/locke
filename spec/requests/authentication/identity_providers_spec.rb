require "rails_helper"

# Signing in with a tenant's own OIDC or SAML provider. How accounts are matched,
# and when a provider creates them, is covered in spec/models/provider_account_spec.rb.
RSpec.describe "Authentication: signing in with a tenant's identity provider", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme", social_sign_in_enabled: false) }
  let_it_be(:okta) { create(:identity_provider, tenant:, name: "Okta") }

  let(:auth_hash) { { provider: "oidc", uid: "ada-sub", info: { email: "ada@example.com", email_verified: true } } }

  before do
    host! "acme.localhost"
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(auth_hash)
  end

  after do
    OmniAuth.config.mock_auth.delete(:oidc)
    OmniAuth.config.test_mode = false
  end

  def identities_of(user) = ActsAsTenant.with_tenant(tenant) { user.identities.map { |identity| [ identity.identity_provider, identity.uid ] } }

  describe "the sign-in page" do
    before_all { create(:identity_provider, tenant:, name: "Entra ID", enabled: false) }

    it "lists the enabled providers" do
      get sign_in_path

      expect(response.body).to include("Okta").and include(okta.auth_path)
      expect(response.body).not_to include("Entra ID")
    end
  end

  describe "the callback" do
    subject(:callback) { get "#{okta.auth_path}/callback" }

    let_it_be(:ada) { create(:user, tenant:, email: "ada@example.com") }

    it "signs in with the identity tied to the provider, even with social sign-in off" do
      callback

      expect(response).to redirect_to(root_path)
      expect(identities_of(ada)).to eq([ [ okta, "ada-sub" ] ])
    end

    context "when the provider says the email isn't verified" do
      let(:auth_hash) { super().deep_merge(info: { email_verified: false }) }

      it "doesn't sign in" do
        callback

        expect(response).to redirect_to(sign_in_path)
        expect(ada.sessions).not_to exist
      end
    end

    context "for another tenant's provider" do
      subject(:callback) { get "#{someone_elses.auth_path}/callback" }

      let_it_be(:someone_elses) { create(:identity_provider) }

      it "doesn't sign in" do
        expect { callback }.not_to change(Session, :count)
      end
    end
  end

  # The real strategy, not OmniAuth's mock, so the per-provider paths are exercised end to end
  context "with SAML" do
    let_it_be(:saml) { create(:identity_provider, :saml, tenant:) }

    before { OmniAuth.config.test_mode = false }

    it "redirects to the provider with a request for this provider's callback" do
      post saml.auth_path

      redirect = URI(response.location)
      expect(redirect.to_s).to start_with("https://idp.example.com/saml/sso")
      request = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(Base64.decode64(Rack::Utils.parse_query(redirect.query)["SAMLRequest"]))
      expect(request).to include("AssertionConsumerServiceURL='http://acme.localhost#{saml.auth_path}/callback'")
    end

    it "serves the metadata to set the provider up with" do
      get "#{saml.auth_path}/metadata"

      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("entityID='http://acme.localhost#{saml.auth_path}/metadata'")
    end
  end
end
