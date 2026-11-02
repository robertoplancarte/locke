require "rails_helper"

RSpec.describe UserMailer do
  let(:user) { create(:user, tenant: create(:tenant, subdomain: "acme")) }

  it "links to the user's tenant" do
    mail = described_class.with(user:).password_reset

    expect(mail.body.encoded).to include("http://acme.localhost/identity/password_reset/edit?sid=")
  end
end
