require "rails_helper"

RSpec.describe User, type: :model do
  describe "two-factor setup" do
    subject(:user) { build(:user, tenant: create(:tenant, two_factor:), otp_required_for_sign_in:) }

    where_cases = {
      # two_factor,  enrolled, can set up, must set up
      [ "off", false ] => [ false, false ],
      [ "off", true ] => [ true, false ],
      [ "optional", false ] => [ true, false ],
      [ "optional", true ] => [ true, false ],
      [ "required", false ] => [ true, true ],
      [ "required", true ] => [ true, false ]
    }

    where_cases.each do |(two_factor, enrolled), (can_set_up, must_set_up)|
      context "when the tenant's 2FA is #{two_factor} and the user #{enrolled ? "has" : "hasn't"} set it up" do
        let(:two_factor) { two_factor }
        let(:otp_required_for_sign_in) { enrolled }

        it { expect(user.can_set_up_two_factor?).to be(can_set_up) }
        it { expect(user.must_set_up_two_factor?).to be(must_set_up) }
      end
    end
  end

  describe "encryption" do
    let_it_be(:tenant) { create(:tenant) }
    let_it_be(:user) { create(:user, tenant:, email: "Ada@Example.com") }

    def stored(attribute) = User.connection.select_value(User.where(id: user.id).select(attribute).to_sql)

    around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

    it "stores the email and OTP secret encrypted" do
      expect(stored(:email)).not_to include("ada@example.com")
      expect(stored(:otp_secret)).not_to include(user.otp_secret)
    end

    it "still finds accounts by email, however it's typed" do
      expect(User.find_by(email: " ADA@example.com ")).to eq(user)
    end

    it "still enforces one account per email in a tenant" do
      expect(build(:user, tenant:, email: "ada@example.com")).to be_invalid
    end
  end

  describe "preferences" do
    subject(:user) { build(:user) }

    it "defaults to UTC and the device's theme" do
      expect(user).to have_attributes(time_zone: "Etc/UTC", theme: "system")
    end

    it "is displayed by name once it has one" do
      expect { user.name = "  Ada   Lovelace " }.to change(user, :display_name).from(user.email).to("Ada Lovelace")
    end

    it "takes a blank name as none" do
      user.name = " "

      expect(user.name).to be_nil
    end

    it "accepts IANA time zones only if they exist" do
      user.time_zone = "America/New_York"
      expect(user.tap(&:validate).errors[:time_zone]).to be_empty

      user.time_zone = "Mars/Olympus_Mons"
      expect(user.tap(&:validate).errors[:time_zone]).to be_present
    end

    it "rejects an unknown theme" do
      user.theme = "sepia"

      expect(user.tap(&:validate).errors[:theme]).to be_present
    end
  end

  describe "#change_password" do
    let_it_be(:tenant) { create(:tenant) }
    let_it_be(:user, refind: true) { create(:user, tenant:) }
    let_it_be(:here) { create(:session, user:) }
    let_it_be(:elsewhere) { create(:session, user:) }

    around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

    it "logs out every other session, keeping the one it was changed from" do
      expect(user.change_password({ password: "a new long password" }, keeping: here)).to be(true)

      expect(user.sessions).to contain_exactly(here)
      expect(user.events.pluck(:action)).to include("password_changed")
    end

    it "logs out every session when changed without one, as from a reset link" do
      user.change_password({ password: "a new long password" })

      expect(user.sessions).to be_empty
    end

    it "keeps every session when the password isn't accepted" do
      expect(user.change_password({ password: "short" })).to be(false)

      expect(user.sessions).to contain_exactly(here, elsewhere)
    end
  end
end
