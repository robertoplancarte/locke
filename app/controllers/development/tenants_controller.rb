module Development
  class TenantsController < ApplicationController
    skip_before_action :authenticate

    def index
      @tenants = Tenant.includes(:domains).order(:name)
    end
  end
end
