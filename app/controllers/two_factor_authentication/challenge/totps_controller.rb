class TwoFactorAuthentication::Challenge::TotpsController < ApplicationController
  include SignInChallenge

  def new
  end

  def create
    @totp = ROTP::TOTP.new(@user.otp_secret, issuer: current_tenant.name)

    if @totp.verify(params[:code], drift_behind: 15)
      redirect_to complete_sign_in(@sign_in.with_second_factor(:otp)), notice: "Signed in successfully"
    else
      redirect_to new_two_factor_authentication_challenge_totp_path, alert: "That code didn't work. Please try again"
    end
  end
end
