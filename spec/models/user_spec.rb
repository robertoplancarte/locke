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
end
