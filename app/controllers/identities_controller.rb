class IdentitiesController < ApplicationController
  before_action :set_user

  def index
    @identities = @user.identities.includes(:identity_provider).order(:created_at)
  end

  def destroy
    @identity = @user.identities.find(params[:id])
    @identity.destroy
    redirect_back_or_to identities_path, notice: "#{@identity.label} has been unlinked"
  end

  private
    def set_user
      @user = Current.user
    end
end
