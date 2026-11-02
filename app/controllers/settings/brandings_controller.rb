module Settings
  class BrandingsController < ApplicationController
    before_action :set_tenant

    def edit
    end

    def update
      attributes = branding_params
      @tenant.logo = nil if attributes.delete(:remove_logo) == "1"
      @tenant.favicon = nil if attributes.delete(:remove_favicon) == "1"

      if @tenant.update(attributes)
        redirect_to edit_settings_branding_path, notice: "Branding saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    # A separate copy, so the layout keeps rendering the saved brand when the form is invalid
    def set_tenant
      @tenant = Tenant.find(current_tenant.id)
    end

    def branding_params
      params.expect(tenant: %i[name primary_color secondary_color logo remove_logo favicon remove_favicon])
    end
  end
end
