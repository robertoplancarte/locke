class TwoFactorAuthentication::Challenge::SecurityKeysController < ApplicationController
  include WebAuthnRelyingParty

  skip_before_action :authenticate

  before_action :set_user

  def new
    respond_to do |format|
      format.html
      format.json { render json: options_for_get }
    end
  end

  def create
    credential, security_key = relying_party.verify_authentication(params.require(:credential), session.delete(:webauthn_challenge)) do |assertion|
      @user.security_keys.find_by!(external_id: assertion.id)
    end

    security_key.update!(sign_count: credential.sign_count)
    sign_in_and_redirect_to_root
  # Malformed input fails while decoding (bad base64 or client data JSON), before verification
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound, JSON::ParserError, ArgumentError
    render json: { error: "That security key couldn't be verified. Please try again" }, status: :unprocessable_content
  end

  private
    def set_user
      @user = User.find_signed!(session[:challenge_token], purpose: :authentication_challenge)
    rescue StandardError
      redirect_to sign_in_path, alert: "That's taking too long. Please re-enter your password and try again"
    end

    def sign_in_and_redirect_to_root
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      render json: { status: "ok", location: root_url }, status: :created
    end

    # The challenge is kept server-side and used once, so a signed assertion can't be replayed
    def options_for_get
      relying_party.options_for_authentication(allow: external_ids).tap do |options|
        session[:webauthn_challenge] = options.challenge
      end
    end

    def external_ids
      @user.security_keys.pluck(:external_id)
    end
end
