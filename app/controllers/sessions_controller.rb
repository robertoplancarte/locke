class SessionsController < ApplicationController
  include SignsIn

  skip_before_action :authenticate, only: %i[ new create ]

  # Password guessing, here and at break-glass sign-in (?local=1) where a default provider hides the form
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to local_sign_in_path, alert: "Try again later" }

  # Users a tenant requires 2FA from can still log out instead of setting it up
  skip_before_action :require_two_factor_setup, only: :destroy

  layout "authentication", only: %i[ new create ]

  before_action :redirect_signed_in_user, only: :new
  before_action :set_session, only: :destroy

  def index
    @sessions = Current.user.sessions.order(created_at: :desc)
  end

  # A tenant's default provider takes people straight there, unless they asked for Locke's own
  # form (break-glass), or the page has something to tell them: an error coming back from the
  # provider, or that they just signed out, which would otherwise sign them straight back in.
  def new
    @default_identity_provider = current_tenant.default_identity_provider unless params[:local]
    @redirect_to_default = @default_identity_provider && flash.empty?
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      begin_sign_in SignIn.new(user, method: :pwd)
    else
      redirect_to local_sign_in_path(email_hint: params[:email]), alert: "That email or password is incorrect"
    end
  end

  def destroy
    @session.destroy; redirect_back_or_to(sessions_path, notice: "That session has been logged out")
  end

  private
    def redirect_signed_in_user
      redirect_to root_path if find_session_record && !session[:reauthenticate]
    end

    def set_session
      @session = Current.user.sessions.find(params[:id])
    end
end
