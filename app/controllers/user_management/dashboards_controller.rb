module UserManagement
  # How many users the tenant has, and the provisioning issues someone has to act on
  class DashboardsController < ApplicationController
    def show
      @counts = UserCounts.new
      @issues = ProvisioningIssue.unresolved.includes(:identity_provider, :user).order(last_occurred_at: :desc)
    end
  end
end
