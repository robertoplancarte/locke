require "rails_helper"

# What a provider's SCIM client can do to the tenant's users. The endpoints that
# call this are covered by smoke tests in spec/requests/scim/users_spec.rb.
RSpec.describe UserProvisioning do
  subject(:provisioning) { described_class.new(identity_provider) }

  let_it_be(:tenant) { create(:tenant) }
  let_it_be(:identity_provider) { create(:identity_provider, tenant:, name: "Keycloak") }
  let_it_be(:other_provider) { create(:identity_provider, tenant:, name: "Okta") }

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe "#create" do
    it "adds a verified account the provider manages" do
      user = provisioning.create(email: "ada@example.com", name: "Ada Lovelace", external_id: "kc-1", active: true)

      expect(user).to be_persisted
      expect(user).to have_attributes(email: "ada@example.com", name: "Ada Lovelace", external_id: "kc-1",
        managed_by: identity_provider, verified: true, deactivated_at: nil)
    end

    it "adds it deactivated when the provider says it's inactive" do
      expect(provisioning.create(email: "ada@example.com", active: false)).not_to be_active
    end

    context "when an account has the email already" do
      let!(:ada) { create(:user, tenant:, email: "ada@example.com", verified: false) }

      it "takes it over, as the provider vouches for the email" do
        expect(provisioning.create(email: "ada@example.com", name: "Ada")).to eq(ada)
        expect(ada.reload).to have_attributes(managed_by: identity_provider, name: "Ada", verified: true)
      end

      it "leaves it alone when another provider manages it, and reports why" do
        ada.update!(managed_by: other_provider)

        user = provisioning.create(email: "ada@example.com", name: "Ada")

        expect(user.errors).to be_of_kind(:base, :managed_elsewhere)
        expect(ada.reload).to have_attributes(managed_by: other_provider, name: nil)
        expect(ProvisioningIssue.sole).to have_attributes(user: ada, identity_provider:, source: "scim",
          message: "Keycloak couldn't update ada@example.com: Okta manages this account")
      end
    end

    it "reports an account it can't add" do
      user = provisioning.create(email: "not an email")

      expect(user).not_to be_persisted
      expect(ProvisioningIssue.sole).to have_attributes(user: nil, details: { "email" => "not an email" },
        message: "Keycloak couldn't add not an email: Email is invalid")
    end
  end

  describe "#update" do
    let!(:user) { create(:user, tenant:, email: "ada@example.com", managed_by: identity_provider) }

    it "changes only the attributes given, keeping the email verified" do
      provisioning.update(user, email: "ada@lovelace.example")

      expect(user.reload).to have_attributes(email: "ada@lovelace.example", verified: true, external_id: nil)
    end

    it "deactivates and reactivates the account" do
      expect { provisioning.update(user, active: false) }.to change { user.reload.active? }.to(false)
      expect { provisioning.update(user, active: true) }.to change { user.reload.active? }.to(true)
    end

    context "when another account has the new email" do
      before { create(:user, tenant:, email: "taken@example.com") }

      it "keeps the old one, reporting the conflict once however often it's sent" do
        2.times { provisioning.update(user, email: "taken@example.com") }

        expect(user.reload.email).to eq("ada@example.com")
        expect(user.errors).to be_of_kind(:email, :taken)
        expect(ProvisioningIssue.sole).to have_attributes(user:, occurrences: 2,
          message: "Keycloak couldn't update ada@example.com: Email has already been taken")
      end
    end
  end
end
