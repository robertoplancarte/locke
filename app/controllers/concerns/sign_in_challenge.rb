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
      if (@sign_in = SignIn.from_challenge_token(session[:sign_in_challenge]))
        @user = @sign_in.user
      else
        redirect_to sign_in_path, alert: "That's taking too long. Please sign in again"
      end
    end
end
