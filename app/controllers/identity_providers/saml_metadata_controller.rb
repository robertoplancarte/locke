module IdentityProviders
  # The service provider metadata a tenant uploads to their SAML identity provider
  class SamlMetadataController < ApplicationController
    skip_before_action :authenticate

    def show
      identity_provider = IdentityProvider.saml.find(params[:identity_provider_id])
      settings = OneLogin::RubySaml::Settings.new(identity_provider.strategy_options(request.base_url))

      render xml: OneLogin::RubySaml::Metadata.new.generate(settings)
    end
  end
end
