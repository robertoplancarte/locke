require "rails_helper"

RSpec.describe Oauth::BackchannelLogoutJob, type: :job do
  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:app) { create(:oauth_application, :backchannel_logout) }

  it "tells the app, inside the tenant the session was on" do
    allow(OauthApplication).to receive(:find).with(app.id).and_return(app)
    allow(app).to receive(:log_out!) { expect(ActsAsTenant.current_tenant).to eq(tenant) }

    described_class.new.perform(tenant, app.id, sub: "usr_1", sid: "ses_1")

    expect(app).to have_received(:log_out!).with(tenant, sub: "usr_1", sid: "ses_1")
  end
end
