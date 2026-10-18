class Sessions::PasswordlessesController < ApplicationController
  skip_before_action :authenticate

  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to sign_in_path, alert: "Try again later" }
  before_action :require_sign_in_links_enabled
  before_action :set_user, only: :edit

  def edit
    session_record = @user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

    revoke_tokens; redirect_to(root_path, notice: "Signed in successfully")
  end

  def create
    if @user = User.find_by(email: params[:email], verified: true)
      send_passwordless_email
      redirect_to sign_in_path, notice: "Check your email for sign in instructions"
    else
      redirect_to sign_in_path(email_hint: params[:email]), alert: "You can't sign in until you verify your email"
    end
  end

  private
    def require_sign_in_links_enabled
      redirect_to sign_in_path, alert: "Sign-in links are turned off for #{current_tenant.name}" unless current_tenant.sign_in_links_enabled?
    end

    def set_user
      token = SignInToken.joins(:user).find_signed!(params[:sid]); @user = token.user
    rescue StandardError
      redirect_to sign_in_path, alert: "That sign in link is invalid"
    end

    def send_passwordless_email
      UserMailer.with(user: @user).passwordless.deliver_later
    end

    def revoke_tokens
      @user.sign_in_tokens.delete_all
    end
end
