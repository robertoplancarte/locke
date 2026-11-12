module Settings
  module IdentityProviders
    # The token the provider's SCIM client authenticates with. A new one replaces
    # the old one right away; removing it stops the provider managing users here.
    class ScimTokensController < ApplicationController
      before_action :set_identity_provider

      def create
        flash[:scim_token] = @identity_provider.generate_scim_token
        redirect_to edit_settings_identity_provider_path(@identity_provider), notice: "New SCIM token generated. Copy it now: it won't be shown again."
      end

      def destroy
        @identity_provider.revoke_scim_token
        redirect_to edit_settings_identity_provider_path(@identity_provider), notice: "SCIM token removed. #{@identity_provider.name} can no longer manage users here."
      end

      private
        def set_identity_provider
          @identity_provider = current_tenant.identity_providers.find(params[:identity_provider_id])
        end
    end
  end
end
