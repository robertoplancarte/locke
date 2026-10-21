module Settings
  class IdentityProvidersController < ApplicationController
    before_action :set_identity_provider, only: %i[edit update destroy]

    def index
      @identity_providers = current_tenant.identity_providers.order(:created_at)
    end

    def new
      @identity_provider = current_tenant.identity_providers.new(protocol: params[:protocol].presence_in(IdentityProvider.protocols.keys) || "oidc")
    end

    def create
      @identity_provider = current_tenant.identity_providers.new(identity_provider_params)

      if @identity_provider.save
        redirect_to edit_settings_identity_provider_path(@identity_provider), notice: "#{@identity_provider.name} added. Finish setting it up with the details below."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @identity_provider.update(identity_provider_params)
        redirect_to settings_identity_providers_path, notice: "#{@identity_provider.name} saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @identity_provider.destroy
      redirect_to settings_identity_providers_path, notice: "#{@identity_provider.name} removed."
    end

    private

    def set_identity_provider
      @identity_provider = current_tenant.identity_providers.find(params[:id])
    end

    # The protocol is chosen once; a blank secret keeps the saved one, which is never shown again
    def identity_provider_params
      permitted = %i[name enabled issuer client_id client_secret idp_entity_id idp_sso_url idp_certificate]
      permitted << :protocol unless @identity_provider&.persisted?

      params.expect(identity_provider: permitted).tap do |attributes|
        attributes.delete(:client_secret) if attributes[:client_secret].blank? && @identity_provider&.client_secret.present?
      end
    end
  end
end
