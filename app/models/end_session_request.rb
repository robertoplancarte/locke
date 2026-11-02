# An app asking to log someone out of Locke (OIDC RP-Initiated Logout 1.0): the
# ID token it holds, which says whose session it means, and where to send the
# browser afterwards.
# https://openid.net/specs/openid-connect-rpinitiated-1_0.html
class EndSessionRequest
  attr_reader :state, :post_logout_redirect_uri

  def initialize(issuer:, id_token_hint: nil, client_id: nil, post_logout_redirect_uri: nil, state: nil)
    @issuer, @id_token_hint, @client_id, @post_logout_redirect_uri, @state = issuer, id_token_hint, client_id, post_logout_redirect_uri, state
  end

  # The session the hint's ID token was issued under, if the hint is genuine
  def hinted_session
    Session.joins(:user).find_by(sid: hint["sid"], users: { public_id: hint["sub"] }) if hint&.dig("sid")
  end

  # The app asking: named by the hint or by client_id, which must agree when both are given
  def application
    return @application if defined?(@application)

    ids = [ hint&.dig("aud"), @client_id.presence ].compact.uniq
    @application = (OauthApplication.find_by(uid: ids.first) if ids.one?)
  end

  def client_id = application&.uid

  # Only an address the app registered, with its state handed back
  def redirect_uri
    return unless application&.post_logout_redirect_uri?(post_logout_redirect_uri)

    uri = URI(post_logout_redirect_uri)
    uri.query = [ uri.query, ({ state: }.to_query if state.present?) ].compact.join("&").presence
    uri.to_s
  end

  private
    # Claims of an ID token this issuer signed, or nil. Expired ones still count:
    # an ID token is usually long expired by the time someone logs out.
    def hint
      return @hint if defined?(@hint)

      @hint = (decode_hint if @id_token_hint.is_a?(String) && @id_token_hint.present?)
    end

    def decode_hint
      jwks = JWT::JWK::Set.new(Doorkeeper::OpenidConnect.signing_keys)
      claims, = JWT.decode(@id_token_hint, nil, true, algorithms: [ "RS256" ], jwks:, iss: @issuer, verify_iss: true, verify_expiration: false)
      # A logout token is signed the same way, but it isn't an ID token
      claims unless claims.key?("events") || !claims["aud"].is_a?(String)
    rescue JWT::DecodeError
      nil
    end
end
