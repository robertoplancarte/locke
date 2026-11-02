class Sessions::OmniauthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  before_action :set_identity_provider
  before_action :require_social_sign_in_enabled, unless: :identity_provider
  before_action :require_verified_email

  # Matching accounts by email is only safe because every configured provider
  # verifies the emails it returns; otherwise anyone could claim an account by asserting its email.
  # Providers a tenant registers are trusted with its own accounts, as the tenant chose them.
  def create
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
    else
      user = User.new(user_params)
      user.identities.build(identity_params)
      sign_in user
    end
  end

  def failure
    redirect_to sign_in_path, alert: params[:message]
  end

  private
    attr_reader :identity_provider

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
        session_record = user.sessions.create!
        cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

        redirect_to root_path, notice: "Signed in successfully"
      else
        redirect_to sign_in_path, alert: "Authentication failed"
      end
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
