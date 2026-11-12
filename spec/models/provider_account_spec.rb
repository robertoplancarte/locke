require "rails_helper"

# Which account a provider's answer belongs to. The callback that asks is
# covered by smoke tests in spec/requests/authentication/omniauth_spec.rb.
RSpec.describe ProviderAccount do
  subject(:match) { provider_account.match(signed_in_user:) }

  let_it_be(:tenant, refind: true) { create(:tenant) }

  let(:identity_provider) { nil }
  let(:signed_in_user) { nil }
  let(:provider_account) do
    described_class.new(tenant:, provider: "developer", uid: "ada-uid", email: "ada@example.com", identity_provider:)
  end

  around { |example| ActsAsTenant.with_tenant(tenant) { example.run } }

  describe "#match" do
    context "when a user already has the provider account" do
      let_it_be(:owner) { create(:user, tenant:, email: "someone-else@example.com") }
      let_it_be(:identity) { create(:identity, user: owner, uid: "ada-uid", email: "old@example.com") }

      it "signs in its owner, whatever their email" do
        expect(match).to have_attributes(outcome: :sign_in, user: owner, identity:)
      end

      it "keeps the provider account's email current" do
        expect { match }.to change { identity.reload.email }.to("ada@example.com")
      end
    end

    context "when an account has the same email" do
      let_it_be(:ada, refind: true) { create(:user, tenant:, email: "ada@example.com", verified: false) }
      let_it_be(:github) { create(:identity, user: ada, provider: "github", uid: "ada-gh") }

      it "signs in that account, verified, with the provider account added to the others" do
        expect(match).to have_attributes(outcome: :sign_in, user: ada)
        expect(match.user).to be_verified
        expect(match.user.identities).to include(github).and include(have_attributes(provider: "developer", uid: "ada-uid", email: "ada@example.com"))
      end

      context "and someone else is signed in" do
        let(:signed_in_user) { create(:user, tenant:) }

        it "signs in the account with the email instead of linking" do
          expect(match).to have_attributes(outcome: :sign_in, user: ada)
        end
      end
    end

    context "when the email is only known on another tenant" do
      before_all { create(:user, email: "ada@example.com") }

      it "treats it as a new person" do
        expect(match.user).to be_new_record
      end
    end

    context "when the provider account is new and someone is signed in" do
      let(:signed_in_user) { create(:user, tenant:) }

      it "links it to them" do
        expect(match).to have_attributes(outcome: :linked, user: signed_in_user)
        expect(match.identity).to be_persisted.and have_attributes(user: signed_in_user, uid: "ada-uid")
      end
    end

    context "when nobody has the provider account or its email" do
      it "builds a verified account with the provider account" do
        expect(match).to have_attributes(outcome: :sign_in)
        expect(match.user).to be_new_record.and have_attributes(email: "ada@example.com", verified: true)
        expect(match.user.identities.map(&:uid)).to eq([ "ada-uid" ])
      end

      context "and the tenant turned sign-ups off" do
        before { tenant.update!(sign_up_enabled: false) }

        it "is closed" do
          expect(match.outcome).to eq(:closed)
        end
      end
    end

    context "with a tenant's own provider" do
      let_it_be(:okta, refind: true) { create(:identity_provider, tenant:) }
      let(:identity_provider) { okta }

      it "manages the accounts it creates, with the name it gives" do
        account = described_class.new(tenant:, provider: "oidc", uid: "ada-uid", email: "ada@example.com", name: "Ada", identity_provider:)

        expect(account.match.user).to be_new_record.and have_attributes(managed_by: okta, name: "Ada")
      end

      context "when it manages the account it signs in to" do
        let_it_be(:ada, refind: true) { create(:user, tenant:, email: "old@example.com", name: "Old name", managed_by: okta) }
        let_it_be(:identity) { create(:identity, user: ada, tenant:, provider: "oidc", uid: "ada-uid", identity_provider: okta) }

        let(:provider_account) do
          described_class.new(tenant:, provider: "oidc", uid: "ada-uid", email: "ada@example.com", name: "Ada", identity_provider:)
        end

        it "brings its name and email up to date" do
          expect(match.user).to eq(ada)
          expect(ada.reload).to have_attributes(email: "ada@example.com", name: "Ada", verified: true)
        end

        it "keeps the email when another account has the new one, and reports it" do
          create(:user, tenant:, email: "ada@example.com")

          expect(match.user.reload).to have_attributes(email: "old@example.com", name: "Ada")
          expect(ProvisioningIssue.sole).to have_attributes(user: ada, identity_provider: okta, source: "sign_in")
        end
      end

      context "when the same uid is linked at another provider" do
        let_it_be(:ada) { create(:user, tenant:, email: "ada@example.com") }
        let_it_be(:entra_identity) do
          create(:identity, user: ada, tenant:, provider: "developer", uid: "ada-uid", identity_provider: create(:identity_provider, tenant:))
        end

        it "keeps them apart" do
          expect(match.user.identities).to include(entra_identity).and include(have_attributes(identity_provider: okta, uid: "ada-uid"))
        end
      end
    end
  end

  describe "#creates_users?" do
    subject { provider_account.creates_users? }

    context "with one of the app's providers" do
      it { is_expected.to be(true) }

      context "when the tenant turned sign-ups off" do
        before { tenant.update!(sign_up_enabled: false) }

        it { is_expected.to be(false) }
      end
    end

    context "with a tenant's own provider" do
      let_it_be(:okta, refind: true) { create(:identity_provider, tenant:) }
      let(:identity_provider) { okta }

      context "when the tenant turned sign-ups off" do
        before { tenant.update!(sign_up_enabled: false) }

        it "follows the provider's own switch" do
          is_expected.to be(true)
        end
      end

      context "when the provider is set not to" do
        before { okta.update!(creates_users: false) }

        it { is_expected.to be(false) }
      end
    end
  end
end
