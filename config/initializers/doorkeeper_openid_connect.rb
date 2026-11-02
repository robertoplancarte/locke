# OpenID Connect on top of Doorkeeper. Each tenant is its own issuer, at its
# canonical host (Tenant#canonical_host), with discovery and JWKS served there.
Doorkeeper::OpenidConnect.configure do
  # Set per request in TenantFromHost, including on the token endpoint where
  # Doorkeeper has no request to hand over
  issuer { Current.oidc_issuer }

  # Every active key is published; the newest signs. See SigningKey.
  signing_key { SigningKey.pems }
  signing_algorithm :rs256

  subject_types_supported [ :public ]
  # A random public id, never the integer primary key or the (changeable) email
  subject { |user, _application| user.public_id }

  expiration 5.minutes.to_i

  # Tenant-scoped, as the userinfo endpoint runs on the tenant's host
  resource_owner_from_access_token { |access_token| User.find_by(id: access_token.resource_owner_id) }

  # max_age is checked against the session in this browser, not the user's latest sign-in anywhere
  auth_time_from_session { |_session, _request| find_session_record&.authenticated_at }
  auth_time_from_access_token { |access_token| access_token.session&.authenticated_at }
  auth_time_from_resource_owner { |_user| nil }

  # prompt=login and a stale max_age: sign in again, then come back
  # (the sign-in page stays up for someone already signed in while :reauthenticate is set)
  reauthenticate_resource_owner do |_user, return_to|
    session[:return_to] = return_to
    session[:reauthenticate] = true
    redirect_to sign_in_path, notice: "Sign in again to continue"
  end

  # OIDC RP-Initiated Logout (Oauth::LogoutsController)
  end_session_endpoint { "#{Current.oidc_issuer}/oauth/logout" }

  # One account per browser session, so there's nothing to choose between
  select_account_for_resource_owner { |_user, _return_to| }

  claims do
    claim(:email, scope: :email, response: [ :id_token, :user_info ]) { |user| user.email }
    claim(:email_verified, scope: :email, response: [ :id_token, :user_info ]) { |user| user.verified? }
    claim(:name, scope: :profile, response: [ :id_token, :user_info ]) { |user| user.display_name }
    # How the user signed in (RFC 8176), from the session the token came from
    claim(:amr, scope: :openid, response: [ :id_token ]) { |_user, _scopes, access_token| access_token.session&.amr.presence }
    # The session the token came from, as logout tokens name it (OIDC Back-Channel Logout)
    claim(:sid, scope: :openid, response: [ :id_token ]) { |_user, _scopes, access_token| access_token.session&.sid }
  end
end

# Discovery doesn't know about back-channel logout; Session#log_out sends logout
# tokens with sid to every app that registered a backchannel_logout_uri
module AdvertiseBackchannelLogout
  private
    def provider_response
      super.merge(backchannel_logout_supported: true, backchannel_logout_session_supported: true)
    end
end
Rails.application.config.to_prepare do
  Doorkeeper::OpenidConnect::DiscoveryController.prepend(AdvertiseBackchannelLogout)
end
