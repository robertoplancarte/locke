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
end
