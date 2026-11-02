module Settings
  module Applications
    # A new client secret, for when the old one is lost or leaked. The old one
    # stops working right away; tokens already issued keep working until they expire.
    class SecretsController < ApplicationController
      def create
        application = current_tenant.oauth_applications.find(params[:application_id])
        application.renew_secret
        application.save!

        flash[:client_secret] = application.plaintext_secret
        redirect_to settings_application_path(application), notice: "New client secret generated. Copy it now: it won't be shown again."
      end
    end
  end
end
