class TwoFactorAuthentication::Profile::SecurityKeysController < ApplicationController
  include WebAuthnRelyingParty

  before_action :set_user
  before_action :set_security_key, only: %i[ edit update destroy ]

  def index
    @security_keys = @user.security_keys
  end

  def new
    respond_to do |format|
      format.html
      format.json { render json: options_for_create }
    end
  end

  def edit
  end

  def create
    credential = relying_party.verify_registration(params.require(:credential), session.delete(:webauthn_challenge))
    @security_key = @user.security_keys.create!(name: "security key", external_id: credential.id, public_key: credential.public_key, sign_count: credential.sign_count)

    render json: { status: "ok", location: edit_two_factor_authentication_profile_security_key_url(@security_key, confirmation: true) }, status: :created
  # Malformed input fails while decoding (bad base64 or client data JSON), before verification
  rescue WebAuthn::Error, JSON::ParserError, ArgumentError
    render json: { error: "That security key couldn't be verified. Please try again" }, status: :unprocessable_content
  end

  def update
    @security_key.update! name: params[:name]
    redirect_to two_factor_authentication_profile_security_keys_path, notice: "Your changes have been saved"
  end

  def destroy
    @security_key.destroy
    redirect_to two_factor_authentication_profile_security_keys_path, notice: "#{@security_key.name} has been removed"
  end

  private
    def set_user
      @user = Current.user
    end

    def set_security_key
      @security_key = @user.security_keys.find(params[:id])
    end

    # The challenge is kept server-side and used once, so only the key that answered it can be registered
    def options_for_create
      relying_party.options_for_registration(user: user_info, exclude: external_ids).tap do |options|
        session[:webauthn_challenge] = options.challenge
      end
    end

    def user_info
      { id: @user.webauthn_id, name: @user.email }
    end

    def external_ids
      @user.security_keys.pluck(:external_id)
    end
end
