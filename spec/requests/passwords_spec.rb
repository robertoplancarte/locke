require "rails_helper"

# Changing and resetting a password. What a change does to other sessions is
# covered by User#change_password in spec/models/user_spec.rb.
RSpec.describe "Passwords", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }
  let_it_be(:user, refind: true) { create(:user, tenant:) }
  let_it_be(:elsewhere) { create(:session, user:) }

  before { host! "acme.localhost" }

  describe "PATCH /password" do
    before { sign_in_as user }

    it "keeps this browser signed in and logs out the others" do
      patch password_path, params: { password_challenge: "correct horse battery", password: "a new long password", password_confirmation: "a new long password" }

      expect(response).to redirect_to(root_path)
      expect(user.sessions.count).to eq(1)
      expect(user.sessions).not_to include(elsewhere)
    end
  end

  describe "PATCH /identity/password_reset" do
    it "logs out every session" do
      patch identity_password_reset_path, params: { sid: user.generate_token_for(:password_reset), password: "a new long password", password_confirmation: "a new long password" }

      expect(response).to redirect_to(sign_in_path)
      expect(user.sessions).to be_empty
    end
  end
end
