require "rails_helper"

RSpec.describe Identity, type: :model do
  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:user) { create(:user, tenant:) }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe ".link" do
    subject(:link) { described_class.link(user, provider: "developer", uid: "ada-uid", identity_provider: nil, email: "ada@example.com") }

    it "links a new provider account to the user" do
      expect(link).to have_attributes(user:, provider: "developer", uid: "ada-uid", email: "ada@example.com")
      expect(link).to be_persisted
      expect(user.events.pluck(:action)).to include("provider_linked")
    end

    context "when the user already linked it" do
      let_it_be(:identity) { create(:identity, user:, uid: "ada-uid", email: "old@example.com") }

      it "returns it with its email kept current" do
        expect { link }.not_to change(described_class, :count)

        expect(link).to eq(identity)
        expect(identity.reload.email).to eq("ada@example.com")
      end
    end

    context "when someone else linked it" do
      let_it_be(:other) { create(:user, tenant:) }
      let_it_be(:identity) { create(:identity, user: other, uid: "ada-uid") }

      it "leaves it with them" do
        expect(link).to be_nil
        expect(identity.reload.user).to eq(other)
      end
    end

    context "when another user has the provider account's email" do
      let_it_be(:other) { create(:user, tenant:, email: "ada@example.com") }

      it "still links it to the user who asked" do
        expect(link.user).to eq(user)
      end
    end
  end
end
