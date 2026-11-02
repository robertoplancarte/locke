require "rails_helper"

RSpec.describe RecoveryCode, type: :model do
  let_it_be(:user) { create(:user) }

  describe ".regenerate_for" do
    subject(:codes) { described_class.regenerate_for(user) }

    it "replaces the user's codes, storing only their digests" do
      old_code = described_class.regenerate_for(user).first

      expect(codes.size).to eq(10)
      expect(user.recovery_codes.pluck(:code_digest)).to match_array(codes.map { described_class.digest(it) })
      expect(user.recovery_codes.redeem(old_code)).to be(false)
    end
  end

  describe ".redeem" do
    let(:code) { described_class.regenerate_for(user).first }

    it "accepts a code once, however it's typed" do
      expect(user.recovery_codes.redeem(" #{code.upcase} ")).to be(true)
      expect(user.recovery_codes.redeem(code)).to be(false)
    end

    it "rejects another user's code" do
      expect(create(:user).recovery_codes.redeem(code)).to be(false)
    end
  end
end
