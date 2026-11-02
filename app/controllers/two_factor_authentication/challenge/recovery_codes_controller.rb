class TwoFactorAuthentication::Challenge::RecoveryCodesController < ApplicationController
  skip_before_action :authenticate

  before_action :set_user

  def new
  end

  def create
    if @user.recovery_codes.redeem(params[:code])
      sign_in_and_redirect_to_root
    else
      redirect_to new_two_factor_authentication_challenge_recovery_codes_path, alert: "That code didn't work. Please try again"
    end
  end

  private
    def set_user
      @user = User.find_signed!(session[:challenge_token], purpose: :authentication_challenge)
    rescue StandardError
      redirect_to sign_in_path, alert: "That's taking too long. Please re-enter your password and try again"
    end

    def sign_in_and_redirect_to_root
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      redirect_to root_path, notice: "Signed in successfully"
    end
end
