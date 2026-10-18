module Development
  class TenantsController < ApplicationController
    def index
      @tenants = Tenant.includes(:domains).order(:name)
    end
  end
end
