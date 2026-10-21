require "rails_helper"

RSpec.describe IdentityProvider::StrategySetup do
  describe ".on_path?" do
    def env(path) = Rack::MockRequest.env_for(path)

    it "matches a provider's request and callback paths" do
      expect(described_class.on_path?(env("/auth/oidc/7"), protocol: :oidc)).to be(true)
      expect(described_class.on_path?(env("/auth/oidc/7/callback"), protocol: :oidc, callback: true)).to be(true)
    end

    it "keeps request, callback and protocol apart" do
      expect(described_class.on_path?(env("/auth/oidc/7/callback"), protocol: :oidc)).to be(false)
      expect(described_class.on_path?(env("/auth/oidc/7"), protocol: :oidc, callback: true)).to be(false)
      expect(described_class.on_path?(env("/auth/saml/7"), protocol: :oidc)).to be(false)
      expect(described_class.on_path?(env("/auth/oidc/okta"), protocol: :oidc)).to be(false)
    end
  end

  describe ".call" do
    subject(:setup) { described_class.call(env) }

    let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
    let_it_be(:identity_provider) { create(:identity_provider, tenant:) }

    let(:host) { "acme.localhost" }
    let(:path) { "/auth/oidc/#{identity_provider.id}" }
    let(:strategy) { OmniAuth::Strategies::OpenIDConnect.new(nil) }
    let(:env) { Rack::MockRequest.env_for("http://#{host}#{path}", "omniauth.strategy" => strategy) }

    it "configures the strategy with the tenant's provider" do
      setup

      expect(strategy.options.client_options.redirect_uri).to eq("http://acme.localhost#{path}/callback")
      expect(strategy.options.issuer).to eq("https://idp.example.com")
    end

    context "on another tenant's host" do
      let(:host) { "#{create(:tenant).subdomain}.localhost" }

      it { expect { setup }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context "when the provider is off" do
      before { identity_provider.update_column(:enabled, false) }

      it { expect { setup }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context "on a path that isn't a provider's" do
      let(:path) { "/auth/saml/#{identity_provider.id}/metadata" }

      it "leaves the strategy alone" do
        expect { setup }.not_to change { strategy.options.to_h }
      end
    end
  end
end
