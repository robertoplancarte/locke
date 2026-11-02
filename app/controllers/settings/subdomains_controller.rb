module Settings
  class SubdomainsController < ApplicationController
    before_action :set_tenant

    def update
      previous_host = @tenant.host

      if @tenant.update(params.expect(tenant: [ :subdomain ]))
        # Session cookies belong to one host, so whoever was on the old address signs in again at the new one.
        # Custom domains keep working, so someone on one of those stays put.
        if request.host == previous_host && @tenant.host != previous_host
          redirect_to sign_in_url(host: @tenant.host), allow_other_host: true
        else
          redirect_to settings_domains_path, notice: "Your workspace address is #{@tenant.host}."
        end
      else
        @domains = current_tenant.domains.order(:created_at)
        @domain = TenantDomain.new
        render "settings/domains/index", status: :unprocessable_content
      end
    end

    private

    # A separate copy, so the page keeps rendering with the saved address when the new one is invalid
    def set_tenant
      @tenant = Tenant.find(current_tenant.id)
    end
  end
end
