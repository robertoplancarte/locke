require "rails_helper"

RSpec.describe IdentityProvider, type: :model do
  let_it_be(:tenant) { create(:tenant) }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe "validations" do
    context "when OIDC" do
      subject(:identity_provider) { build(:identity_provider, tenant:) }

      it { is_expected.to be_valid }

      it "needs the client details to be enabled" do
        identity_provider.client_secret = ""

        expect(identity_provider).to be_invalid
        expect(identity_provider.errors[:client_secret]).to be_present
      end

      it "can be saved without them while disabled" do
        identity_provider.assign_attributes(enabled: false, issuer: nil, client_id: nil, client_secret: nil)

        expect(identity_provider).to be_valid
      end

      it "requires an https issuer" do
        identity_provider.issuer = "http://idp.example.com"

        expect(identity_provider).to be_invalid
      end
    end

    context "when SAML" do
      subject(:identity_provider) { build(:identity_provider, :saml, tenant:) }

      it { is_expected.to be_valid }

      it "needs the certificate to be enabled" do
        identity_provider.idp_certificate = nil

        expect(identity_provider).to be_invalid
      end

      it "rejects a certificate that isn't one" do
        identity_provider.assign_attributes(enabled: false, idp_certificate: "not a certificate")

        expect(identity_provider).to be_invalid
        expect(identity_provider.errors[:idp_certificate]).to include("must be a PEM-encoded X.509 certificate")
      end
    end

    it "rejects an unknown protocol" do
      expect(build(:identity_provider, tenant:, protocol: "ldap")).to be_invalid
    end
  end

  it "encrypts the client secret" do
    identity_provider = create(:identity_provider, tenant:, client_secret: "s3cret")

    expect(identity_provider.ciphertext_for(:client_secret)).not_to include("s3cret")
    expect(identity_provider.reload.client_secret).to eq("s3cret")
  end

  describe ".linkable" do
    let_it_be(:oidc) { create(:identity_provider, tenant:) }
    let_it_be(:disabled) { create(:identity_provider, tenant:, enabled: false) }
    let_it_be(:saml) { create(:identity_provider, :saml, tenant:) }

    it "is the enabled OIDC providers" do
      expect(described_class.linkable).to contain_exactly(oidc)
    end
  end

  describe "#strategy_options" do
    subject(:options) { identity_provider.strategy_options("https://acme.example.com") }

    context "when OIDC" do
      let(:identity_provider) { build_stubbed(:identity_provider, id: 7, tenant:) }

      it "points the provider back at its own callback" do
        expect(options).to include(issuer: "https://idp.example.com", discovery: true, pkce: true)
        expect(options[:client_options]).to eq(identifier: "client-id", secret: "client-secret", redirect_uri: "https://acme.example.com/auth/oidc/7/callback")
      end
    end

    context "when SAML" do
      let(:identity_provider) { build_stubbed(:identity_provider, :saml, id: 7, tenant:) }

      it "identifies the app by its metadata URL" do
        expect(options).to include(
          sp_entity_id: "https://acme.example.com/auth/saml/7/metadata",
          assertion_consumer_service_url: "https://acme.example.com/auth/saml/7/callback",
          idp_sso_service_url: "https://idp.example.com/saml/sso",
          idp_entity_id: "https://idp.example.com/saml"
        )
      end
    end
  end
end
