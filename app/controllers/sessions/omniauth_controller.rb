# Where a provider sends the user back. Which account that is, and whether it
# can be created, is ProviderAccount's call; this turns the answer into a response.
class Sessions::OmniauthController < ApplicationController
  include SignsIn

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  # Only the callback carries a provider's answer; /auth/failure has none to check
  before_action :set_identity_provider, only: :create
  before_action :require_social_sign_in_enabled, only: :create, unless: :identity_provider
  before_action :require_verified_email, only: :create
  before_action :restore_return_to, only: :create, if: -> { identity_provider&.saml? }

  def create
    return link if linking?

    match = provider_account.match(signed_in_user: find_session_record&.user)
    case match.outcome
    when :sign_in then sign_in match.user
    when :linked then redirect_to identities_path, notice: "#{match.identity.label} is now linked to your account"
    when :closed then redirect_to sign_in_path, alert: "#{current_tenant.name} isn't accepting sign-ups. Ask for an invitation."
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

    # Links the provider account to the signed-in user (see Identity.link); the tab then
    # says it's linked instead of signing in again
    def link
      unless user = find_session_record&.user
        session[:return_to] = account_security_path
        return redirect_to sign_in_path, alert: "Sign in again to link your account"
      end

      if identity = Identity.link(user, email: provider_account.email, **provider_account.key)
        redirect_to linked_identity_path(identity)
      else
        redirect_to account_security_path, alert: "That account is already linked to someone else"
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

    # A SAML provider posts back cross-site, so the browser leaves out the Lax session
    # cookie holding return_to; the sign-in page sent it along as RelayState instead.
    # It's checked for being a local path before it's used.
    def restore_return_to
      session[:return_to] ||= params[:RelayState].presence
    end

    def provider_account
      @provider_account ||= ProviderAccount.new(
        tenant: current_tenant, provider: omniauth.provider, uid: omniauth.uid, email: omniauth.info.email, identity_provider:
      )
    end

    def omniauth
      request.env["omniauth.auth"]
    end
end
