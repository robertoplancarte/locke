# The 2FA challenge screens, which finish a sign-in that's waiting on a second factor
module SignInChallenge
  extend ActiveSupport::Concern
  include SignsIn

  included do
    skip_before_action :authenticate
    before_action :set_sign_in
  end

  private
    def set_sign_in
      if (@sign_in = SignIn.from_challenge_token(session[:sign_in_challenge])).nil?
        redirect_to sign_in_path, alert: "That's taking too long. Please sign in again"
      elsif (refusal = @sign_in.refusal)
        # The account was deactivated or taken over by a provider since the first step
        redirect_to sign_in_path, alert: refusal
      else
        @user = @sign_in.user
      end
    end
end
