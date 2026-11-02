require "rails_helper"

RSpec.describe Session do
  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:user) { create(:user, tenant:) }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe "sid" do
    subject(:session) { create(:session, user:) }

    it "is random, not the id" do
      expect(session.sid).to match(/\Ases_\w{24}\z/).and not_include(session.id.to_s)
    end
  end

  describe "#log_out" do
    subject(:log_out) { session.log_out }

    let_it_be(:session, refind: true) { create(:session, user:) }
    let_it_be(:listening_app) { create(:oauth_application, :backchannel_logout) }
    let_it_be(:quiet_app) { create(:oauth_application) }
    let_it_be(:token) { create(:oauth_access_token, session:, application: listening_app) }
    let_it_be(:quiet_token) { create(:oauth_access_token, session:, application: quiet_app) }
    let_it_be(:grant) { create(:oauth_access_grant, session:, application: listening_app) }
    let_it_be(:other_session_token) { create(:oauth_access_token, session: create(:session, user:), application: listening_app) }

    it "ends the session" do
      log_out

      expect(described_class).not_to exist(session.id)
      expect(user.events.pluck(:action)).to include("signed_out")
    end

    it "revokes its codes and tokens, refresh tokens included" do
      log_out

      expect([ token, quiet_token, grant ].map { |record| record.reload.revoked? }).to all(be(true))
      expect(token.reload.session_id).to be_nil
    end

    it "leaves other sessions' tokens alone" do
      log_out

      expect(other_session_token.reload).not_to be_revoked
    end

    it "tells the apps that take back-channel logout" do
      expect { log_out }.to have_enqueued_job(Oauth::BackchannelLogoutJob).once
        .with(tenant, listening_app.id, sub: user.public_id, sid: session.sid)
    end
  end

  describe "#reauthenticate!" do
    subject(:reauthenticate) { session.reauthenticate!(amr: %w[pwd otp mfa], identity_provider: nil) }

    let(:session) { create(:session, user:, amr: [ "fed" ], authenticated_at: 1.day.ago) }

    it "refreshes how and when the user signed in, keeping the sid apps know" do
      expect { reauthenticate }.not_to change(session, :sid)

      expect(session).to have_attributes(amr: %w[pwd otp mfa], authenticated_at: be_within(1).of(Time.current))
      expect(user.events.pluck(:action)).to include("signed_in_again")
    end
  end

  RSpec::Matchers.define_negated_matcher :not_include, :include
end
