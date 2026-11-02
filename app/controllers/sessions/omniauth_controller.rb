class Sessions::OmniauthController < ApplicationController
  include SignsIn

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  # Only the callback carries a provider's answer; /auth/failure has none to check
  before_action :set_identity_provider, only: :create
  before_action :require_social_sign_in_enabled, only: :create, unless: :identity_provider
  before_action :require_verified_email, only: :create
  before_action :restore_return_to, only: :create, if: -> { identity_provider&.saml? }

  # Matching accounts by email is only safe because every configured provider
  # verifies the emails it returns; otherwise anyone could claim an account by asserting its email.
  # Providers a tenant registers are trusted with its own accounts, as the tenant chose them.
  def create
    return link if linking?

    if identity = Identity.find_by(omniauth_params)
      identity.update!(email: omniauth.info.email)
      sign_in identity.user
    elsif user = User.find_by(email: omniauth.info.email)
      user.verified = true
      user.identities.build(identity_params)
      sign_in user
    elsif session_record = find_session_record
      identity = session_record.user.identities.create!(identity_params)
      redirect_to identities_path, notice: "#{identity.label} is now linked to your account"
    elsif creates_users?
      user = User.new(user_params)
      user.identities.build(identity_params)
      sign_in user
    else
      redirect_to sign_in_path, alert: "#{current_tenant.name} isn't accepting sign-ups. Ask for an invitation."
    end
  end

  def failure
    redirect_to sign_in_path, alert: params[:message]
  end

  private
    attr_reader :identity_provider

    # The settings page asks for linking (link=1), opening the provider in a new tab
    def linking?
      request.env["omniauth.params"].to_h["link"] == "1"
    end

    # Links the provider account to the signed-in user, whatever its email, as they asked for it.
    # The tab then says it's linked instead of signing in again.
    def link
      unless user = find_session_record&.user
        session[:return_to] = account_security_path
        return redirect_to sign_in_path, alert: "Sign in again to link your account"
      end

      identity = Identity.find_or_initialize_by(omniauth_params)
      if identity.persisted? && identity.user != user
        redirect_to account_security_path, alert: "That #{identity.provider_name} account is already linked to someone else"
      else
        identity.update!(user:, email: omniauth.info.email)
        redirect_to linked_identity_path(identity)
      end
    end

    # Tenant-scoped, so a callback can't use another tenant's provider
    def set_identity_provider
      @identity_provider = IdentityProvider.enabled.find_by!(protocol: params[:protocol], id: params[:identity_provider_id]) if params[:identity_provider_id]
    end

    def require_social_sign_in_enabled
      redirect_to sign_in_path, alert: "Social sign-in is turned off for #{current_tenant.name}" unless current_tenant.social_sign_in_enabled?
    end

    # OIDC providers say when they haven't verified an email; SAML ones have no way to
    def require_verified_email
      redirect_to sign_in_path, alert: "Your email address isn't verified with your provider" if omniauth.info.email_verified == false
    end

    def sign_in(user)
      if user.save
        begin_sign_in SignIn.new(user, method: :fed, identity_provider:)
      else
        redirect_to sign_in_path, alert: "Authentication failed"
      end
    end

    # A tenant's own provider has its own switch, as tenants that turn sign-ups off
    # often still want their provider to create accounts; the app's providers follow sign-ups.
    def creates_users?
      identity_provider ? identity_provider.creates_users? : current_tenant.sign_up_enabled?
    end

    # A SAML provider posts back cross-site, so the browser leaves out the Lax session
    # cookie holding return_to; the sign-in page sent it along as RelayState instead.
    # It's checked for being a local path before it's used.
    def restore_return_to
      session[:return_to] ||= params[:RelayState].presence
    end

    def user_params
      { email: omniauth.info.email, password: SecureRandom.base58, verified: true }
    end

    # What identifies the provider account
    def omniauth_params
      { provider: omniauth.provider, uid: omniauth.uid, identity_provider: }
    end

    def identity_params
      omniauth_params.merge(email: omniauth.info.email)
    end

    def omniauth
      request.env["omniauth.auth"]
    end
end
