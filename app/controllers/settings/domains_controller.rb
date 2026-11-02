module Settings
  class DomainsController < ApplicationController
    def index
      @domains = current_tenant.domains.order(:created_at)
      @domain = TenantDomain.new
      @tenant = current_tenant
    end

    def create
      @domain = current_tenant.claim_domain(params.expect(tenant_domain: [ :hostname ])[:hostname])

      if @domain.persisted?
        redirect_to settings_domains_path, notice: "#{@domain.hostname} added. Add the DNS records below to verify it."
      else
        @domains = current_tenant.domains.order(:created_at)
        @tenant = current_tenant
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      domain = current_tenant.domains.find(params[:id])
      domain.release_later

      redirect_to settings_domains_path, notice: "#{domain.hostname} is being removed."
    end
  end
end
