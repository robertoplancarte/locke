class TwoFactorAuthentication::Profile::RecoveryCodesController < ApplicationController
  before_action :set_user
  # Keeps the page with the codes out of the browser's cache and back button
  before_action :no_store

  # Codes are only readable when generated, so a user's first visit generates them
  def index
    if @user.recovery_codes.exists?
      @unused_count = @user.recovery_codes.unused.count
    else
      @codes = RecoveryCode.regenerate_for(@user)
    end
  end

  # Rendered, not redirected: the new codes can't be shown again after this response
  def create
    @codes = RecoveryCode.regenerate_for(@user)
    flash.now[:notice] = "Your new recovery codes have been generated"
    render :index
  end

  private
    def set_user
      @user = Current.user
    end
end
