# Turns a SignIn into a signed-in browser: sends the user to the 2FA challenge
# when they owe a second factor, otherwise sets the session cookie and takes them
# back to the page that asked them to sign in.
module SignsIn
  extend ActiveSupport::Concern

  private
    def begin_sign_in(sign_in)
      if (refusal = sign_in.refusal)
        redirect_to local_sign_in_path, alert: refusal
      elsif sign_in.second_factor_required?
        session[:sign_in_challenge] = sign_in.challenge_token
        redirect_to new_two_factor_authentication_challenge_totp_path
      else
        redirect_to complete_sign_in(sign_in), notice: "Signed in successfully"
      end
    end

    # Starts the session and returns where to go next, leaving the response to the
    # caller (the security key challenge answers with JSON)
    def complete_sign_in(sign_in)
      return_to = session[:return_to]
      # Signing in again (an app asked for prompt=login or max_age) refreshes the session already here
      previous_session = find_session_record
      # A fresh Rails session, so nothing planted before sign-in carries over into it
      reset_session

      cookies.signed.permanent[:session_token] = { value: sign_in.complete!(replacing: previous_session).id, httponly: true }
      local_path(return_to) || root_path
    end

    # Back to the sign-in form, keeping it shown (?local=1) when the tenant's
    # default provider would otherwise take people away from it
    def local_sign_in_path(**params)
      sign_in_path(**params, local: (1 if current_tenant.default_identity_provider_id))
    end

    # Only paths on this host, so a crafted return_to can't send people to another site.
    # Browsers read "//host" and "/\host" as another host, and drop tabs and newlines.
    def local_path(path)
      path if path.is_a?(String) && path.match?(%r{\A/(?![/\\])}) && URI.parse(path).host.nil?
    rescue URI::InvalidURIError
      nil
    end
end
