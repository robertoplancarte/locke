module UserManagement
  module Issues
    # Marks an issue as dealt with. If the provider runs into it again, it opens a new one.
    class ResolutionsController < ApplicationController
      def create
        ProvisioningIssue.find(params[:issue_id]).resolve
        redirect_to user_management_root_path, notice: "Issue marked as resolved"
      end
    end
  end
end
