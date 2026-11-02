class TwoFactorAuthentication::Challenge::SecurityKeysController < ApplicationController
  include WebAuthnRelyingParty
  include SignInChallenge

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
    render json: { status: "ok", location: complete_sign_in(@sign_in.with_second_factor(:hwk)) }, status: :created
  # Malformed input fails while decoding (bad base64 or client data JSON), before verification
  rescue WebAuthn::Error, ActiveRecord::RecordNotFound, JSON::ParserError, ArgumentError
    render json: { error: "That security key couldn't be verified. Please try again" }, status: :unprocessable_content
  end

  private
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
