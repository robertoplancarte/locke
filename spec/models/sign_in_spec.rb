require "rails_helper"

RSpec.describe SignIn do
  include ActiveSupport::Testing::TimeHelpers

  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:user) { create(:user, tenant:) }
  let_it_be(:user_with_2fa) { create(:user, tenant:, otp_required_for_sign_in: true) }
  let_it_be(:identity_provider) { create(:identity_provider, tenant:) }
  let_it_be(:other_tenant) { create(:tenant) }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe "#second_factor_required?" do
    it "is false for users without 2FA" do
      expect(described_class.new(user, method: :pwd)).not_to be_second_factor_required
    end

    it "is true for users with 2FA, whatever the first factor" do
      %i[pwd email fed].each do |method|
        expect(described_class.new(user_with_2fa, method:)).to be_second_factor_required
      end
    end

    it "is false once a second factor is added" do
      expect(described_class.new(user_with_2fa, method: :fed).with_second_factor(:hwk)).not_to be_second_factor_required
    end
  end

  describe "#complete!" do
    it "records how and when the user signed in" do
      freeze_time do
        session = described_class.new(user, method: :fed, identity_provider:).complete!

        expect(session).to have_attributes(user:, amr: [ "fed" ], identity_provider:, authenticated_at: Time.current)
      end
    end

    it "adds mfa when a second factor was used" do
      session = described_class.new(user_with_2fa, method: :pwd).with_second_factor(:otp).complete!

      expect(session.amr).to eq(%w[pwd otp mfa])
    end

    context "when the user signs in again in the same browser" do
      let(:previous) { user.sessions.create!(amr: [ "fed" ]) }

      it "refreshes that session instead of starting another" do
        session = described_class.new(user, method: :pwd).complete!(replacing: previous)

        expect(session).to eq(previous)
        expect(session.reload.amr).to eq([ "pwd" ])
      end
    end

    context "when someone else was signed in in this browser" do
      let(:previous) { user_with_2fa.sessions.create! }

      it "starts a session of the user's own" do
        session = described_class.new(user, method: :pwd).complete!(replacing: previous)

        expect(session).to be_persisted.and have_attributes(user:)
        expect(session).not_to eq(previous)
      end
    end

    it "refuses while a second factor is owed" do
      expect { described_class.new(user_with_2fa, method: :email).complete! }.to raise_error(/second factor/)
      expect(Session.where(user: user_with_2fa)).to be_empty
    end
  end

  describe "challenge tokens" do
    it "round-trip the sign-in" do
      token = described_class.new(user_with_2fa, method: :fed, identity_provider:).challenge_token

      expect(described_class.from_challenge_token(token)).to have_attributes(user: user_with_2fa, amr: [ "fed" ], identity_provider:)
    end

    it "expire" do
      token = described_class.new(user_with_2fa, method: :pwd).challenge_token

      travel 21.minutes do
        expect(described_class.from_challenge_token(token)).to be_nil
      end
    end

    it "don't work on another tenant" do
      token = described_class.new(user_with_2fa, method: :pwd).challenge_token

      ActsAsTenant.with_tenant(other_tenant) do
        expect(described_class.from_challenge_token(token)).to be_nil
      end
    end

    it "reject tampering and junk" do
      token = described_class.new(user_with_2fa, method: :pwd).challenge_token

      expect(described_class.from_challenge_token(token.reverse)).to be_nil
      expect(described_class.from_challenge_token(nil)).to be_nil
    end
  end

  describe "#refusal" do
    it "is nil for an active user nobody manages" do
      expect(described_class.new(user, method: :pwd).refusal).to be_nil
    end

    it "refuses a deactivated user, however they sign in" do
      deactivated = create(:user, tenant:, deactivated_at: Time.current)

      expect(described_class.new(deactivated, method: :fed, identity_provider:).refusal).to eq("Your account has been deactivated")
    end

    context "when a provider manages the user" do
      let(:managed) { create(:user, tenant:, managed_by: identity_provider) }

      it "only lets them sign in through it" do
        expect(described_class.new(managed, method: :fed, identity_provider:).refusal).to be_nil
        expect(described_class.new(managed, method: :pwd).refusal).to include("Sign in with #{identity_provider.name}")
        expect(described_class.new(managed, method: :fed, identity_provider: create(:identity_provider, tenant:)).refusal).to be_present
      end

      it "won't start a session another way" do
        expect { described_class.new(managed, method: :email).complete! }.to raise_error(/Sign-in refused/)
      end
    end
  end
end
