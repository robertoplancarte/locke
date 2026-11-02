# Locke is the OAuth 2.0 / OpenID Connect provider for apps. Every endpoint is
# served per tenant host (see config/routes.rb), and grants and tokens are
# tenant-scoped, so a tenant's codes and tokens only work on its own hosts.
Doorkeeper.configure do
  orm :active_record

  base_controller "OauthController"
  base_metal_controller "OauthMetalController"

  application_class "OauthApplication"
  access_grant_class "OauthAccessGrant"
  access_token_class "OauthAccessToken"

  # Runs in the authorization controller. Signs people in with the usual page and
  # comes back here afterwards; users a tenant requires 2FA from must set it up first.
  resource_owner_authenticator do
    session_record = find_session_record

    if session_record && !session_record.user.must_set_up_two_factor?
      Current.session = session_record
      session_record.user
    else
      session[:return_to] = request.fullpath
      redirect_to session_record ? new_two_factor_authentication_profile_totp_path : sign_in_path
      nil
    end
  end

  # Doorkeeper's own app screens are off (config/routes.rb): tenants register
  # theirs under Settings, and operators the global ones with bin/rails oauth:app:global
  admin_authenticator { head :forbidden }

  # Authorization code with PKCE only, for every client
  grant_flows %w[authorization_code]
  force_pkce
  pkce_code_challenge_methods %w[S256]

  authorization_code_expires_in 5.minutes
  access_token_expires_in 15.minutes
  use_refresh_token

  # Only digests are stored; the plaintext is shown once, when an app is registered
  hash_token_secrets
  hash_application_secrets

  # First-party and tenant-registered apps are trusted: no consent screen
  skip_authorization { true }

  default_scopes :openid
  optional_scopes :profile, :email
  enforce_configured_scopes

  # Which Locke session a grant came from, carried from grant to token to
  # refreshed token. Oauth::AuthorizationsController sets it from the signed-in session.
  custom_access_token_attributes [ :session_id ]

  access_token_methods :from_bearer_authorization
end

# force_pkce only covers public clients; Locke requires PKCE from confidential ones
# too (OAuth 2.1), so a stolen code is useless without the verifier.
module RequirePkceFromEveryClient
  private
    def validate_code_challenge
      return true if code_challenge.present?

      @invalid_request_reason = :invalid_code_challenge
      false
    end
end
Doorkeeper::OAuth::PreAuthorization.prepend(RequirePkceFromEveryClient)
