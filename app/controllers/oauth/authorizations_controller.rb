# Doorkeeper's authorization endpoint, recording which Locke session approved
# each code. Doorkeeper copies session_id from grant to token to refreshed
# token, so logging out of Locke can find everything that session issued.
class Oauth::AuthorizationsController < Doorkeeper::AuthorizationsController
  private
    # Doorkeeper reads custom token attributes from the request, so a client
    # could otherwise name any session. Always the one that signed in here.
    def pre_auth_params
      super.merge(session_id: Current.session&.id)
    end
end
