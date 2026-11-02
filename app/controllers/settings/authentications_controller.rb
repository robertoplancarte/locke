module Settings
  class AuthenticationsController < ApplicationController
    def edit
    end

    def update
      if current_tenant.update(authentication_params)
        redirect_to edit_settings_authentication_path, notice: "Authentication settings saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def authentication_params
      params.expect(tenant: [ :sign_up_enabled, :sign_in_links_enabled, :social_sign_in_enabled, :two_factor, :default_identity_provider_id ])
    end
  end
end
