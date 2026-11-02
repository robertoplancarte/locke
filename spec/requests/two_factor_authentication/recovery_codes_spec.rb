require "rails_helper"

RSpec.describe "Two-factor recovery codes", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

  before { host! "acme.localhost" }

  describe "managing them" do
    let_it_be(:user) { create(:user, tenant:) }

    before { sign_in_as user }

    it "shows codes once, when they're first generated" do
      get two_factor_authentication_profile_recovery_codes_path

      expect(response.body).to include("won't be shown again")
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(user.recovery_codes.count).to eq(10)

      get two_factor_authentication_profile_recovery_codes_path

      expect(response.body).to include("10 unused recovery codes")
      expect(response.body).not_to include('id="recovery_codes"')
    end

    it "shows the new set after regenerating" do
      post two_factor_authentication_profile_recovery_codes_path

      codes = Nokogiri::HTML(response.body).css("#recovery_codes code").map(&:text)
      expect(codes.map { RecoveryCode.digest(it) }).to match_array(user.recovery_codes.pluck(:code_digest))
    end
  end

  describe "signing in with one" do
    let_it_be(:user) { create(:user, tenant:, otp_required_for_sign_in: true) }
    let_it_be(:code) { RecoveryCode.regenerate_for(user).first }

    before { sign_in_as user }

    it "signs in once per code" do
      post two_factor_authentication_challenge_recovery_codes_path, params: { code: }

      expect(response).to redirect_to(root_path)
      expect(user.sessions).to exist

      delete session_path(user.sessions.sole)
      sign_in_as user
      post two_factor_authentication_challenge_recovery_codes_path, params: { code: }

      expect(response).to redirect_to(new_two_factor_authentication_challenge_recovery_codes_path)
    end
  end
end
