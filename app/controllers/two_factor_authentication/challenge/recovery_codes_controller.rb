class TwoFactorAuthentication::Challenge::RecoveryCodesController < ApplicationController
  include SignInChallenge

  def new
  end

  def create
    if @user.recovery_codes.redeem(params[:code])
      redirect_to complete_sign_in(@sign_in.with_second_factor(:rc)), notice: "Signed in successfully"
    else
      redirect_to new_two_factor_authentication_challenge_recovery_codes_path, alert: "That code didn't work. Please try again"
    end
  end
end
