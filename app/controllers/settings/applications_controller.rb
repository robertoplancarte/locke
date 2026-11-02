module Settings
  # A tenant's own OIDC apps. The global apps every tenant shares stay with
  # bin/rails oauth:app:global, since no one tenant owns them.
  class ApplicationsController < ApplicationController
    before_action :set_application, only: %i[show edit update destroy]

    def index
      @applications = current_tenant.oauth_applications.order(:created_at)
    end

    def show
    end

    def new
      @application = current_tenant.oauth_applications.new
    end

    # Only a digest of the secret is stored, so this is the one time it can be shown
    def create
      @application = current_tenant.oauth_applications.new(application_params)

      if @application.save
        flash[:client_secret] = @application.plaintext_secret
        redirect_to settings_application_path(@application), notice: "#{@application.name} registered. Copy its client secret now: it won't be shown again."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @application.update(application_params)
        redirect_to settings_application_path(@application), notice: "#{@application.name} saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @application.destroy
      redirect_to settings_applications_path, notice: "#{@application.name} removed."
    end

    private

    def set_application
      @application = current_tenant.oauth_applications.find(params[:id])
    end

    # Both URI lists are edited one per line
    def application_params
      params.expect(oauth_application: %i[name redirect_uri confidential backchannel_logout_uri post_logout_redirect_uris]).tap do |attributes|
        attributes[:post_logout_redirect_uris] = attributes[:post_logout_redirect_uris].split if attributes.key?(:post_logout_redirect_uris)
      end
    end
  end
end
