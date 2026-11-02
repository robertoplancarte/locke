# Where apps send people to log out of Locke (OIDC RP-Initiated Logout), and
# back again afterwards. Ending the session tells every other app through
# back-channel logout (Session#log_out).
class Oauth::LogoutsController < OauthController
  # Apps link or post here from their own pages. Without a genuine ID token
  # this only asks, and that confirmation is protected as usual.
  skip_forgery_protection only: :show

  layout "authentication"

  def show
    @end_session = end_session
    if (hinted_session = end_session.hinted_session)
      log_out hinted_session
    elsif find_session_record
      render :show
    else
      finish
    end
  end

  def destroy
    log_out find_session_record
  end

  private
    def end_session
      @end_session ||= EndSessionRequest.new(issuer: Current.oidc_issuer, **params.permit(:id_token_hint, :client_id, :post_logout_redirect_uri, :state).to_h.symbolize_keys)
    end

    def log_out(session_record)
      if session_record&.id == find_session_record&.id
        cookies.delete(:session_token)
        reset_session
      end
      session_record&.log_out
      finish
    end

    def finish
      if (uri = end_session.redirect_uri)
        redirect_to uri, allow_other_host: true
      else
        redirect_to sign_in_path, notice: "You're logged out"
      end
    end
end
