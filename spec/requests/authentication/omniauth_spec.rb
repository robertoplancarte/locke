require "rails_helper"

RSpec.describe "Authentication: signing in with a provider", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme") }

  subject(:callback) { post "/auth/developer/callback" }

  before do
    host! "acme.localhost"
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(provider: "developer", uid: "ada-uid", info: { email: "Ada@example.com" })
  end

  after do
    OmniAuth.config.mock_auth.delete(:developer)
    OmniAuth.config.test_mode = false
  end

  def users = ActsAsTenant.with_tenant(tenant) { User.all }
  def identities_of(user) = ActsAsTenant.with_tenant(user.tenant) { user.identities.pluck(:provider, :uid) }

  it "signs up a new email with the identity" do
    expect { callback }.to change { users.count }.by(1)

    user = users.last
    expect(user).to have_attributes(email: "ada@example.com", verified: true)
    expect(identities_of(user)).to eq([ [ "developer", "ada-uid" ] ])
    expect(response).to redirect_to(root_path)
  end

  it "doesn't sign up a new email when the tenant turned sign-ups off" do
    tenant.update!(sign_up_enabled: false)

    expect { callback }.not_to change { users.count }
    expect(response).to redirect_to(sign_in_path)
  end

  it "still signs in existing accounts when the tenant turned sign-ups off" do
    tenant.update!(sign_up_enabled: false)
    user = create(:user, tenant:, email: "ada@example.com")

    callback

    expect(user.sessions).to exist
  end

  it "remembers the provider account's email, and keeps it current" do
    user = create(:user, tenant:, email: "ada@example.com")
    identity = create(:identity, user:, uid: "ada-uid", email: "old@example.com")

    callback

    expect(ActsAsTenant.with_tenant(tenant) { identity.reload.email }).to eq("ada@example.com")
  end

  it "signs in the user who owns the identity, even under a different email" do
    user = create(:user, tenant:, email: "someone-else@example.com")
    create(:identity, user:, uid: "ada-uid")

    expect { callback }.not_to change { users.count }

    expect(identities_of(user)).to eq([ [ "developer", "ada-uid" ] ])
    expect(user.sessions).to exist
    expect(response).to redirect_to(root_path)
  end

  it "links the identity to an existing account with the same email" do
    user = create(:user, tenant:, email: "ada@example.com", verified: false)

    expect { callback }.not_to change { users.count }

    expect(user.reload).to be_verified
    expect(identities_of(user)).to eq([ [ "developer", "ada-uid" ] ])
    expect(user.sessions).to exist
  end

  it "keeps the user's other identities when linking another" do
    user = create(:user, tenant:, email: "ada@example.com")
    create(:identity, user:, provider: "github", uid: "ada-gh")

    callback

    expect(identities_of(user)).to contain_exactly([ "github", "ada-gh" ], [ "developer", "ada-uid" ])
    expect(user.sessions).to exist
  end

  context "when signed in" do
    let_it_be(:user) { create(:user, tenant:, email: "grace@example.com") }

    before { sign_in_as user }

    it "links an identity with an unknown email to the signed in user" do
      expect { callback }.not_to change { users.count }

      expect(identities_of(user)).to eq([ [ "developer", "ada-uid" ] ])
      expect(response).to redirect_to(identities_path)
    end

    it "signs in the account with the identity's email instead" do
      ada = create(:user, tenant:, email: "ada@example.com")

      callback

      expect(identities_of(ada)).to eq([ [ "developer", "ada-uid" ] ])
      expect(identities_of(user)).to be_empty
      expect(response).to redirect_to(root_path)
    end
  end

  # The linking rules themselves are covered by Identity.link in spec/models/identity_spec.rb
  context "when linking from settings" do
    # Starts at the request phase, as the settings page's button does, so link=1 comes back as omniauth.params
    subject(:link) do
      post "/auth/developer", params: { link: 1 }
      follow_redirect!
    end

    let_it_be(:user) { create(:user, tenant:, email: "grace@example.com") }
    let_it_be(:ada) { create(:user, tenant:, email: "ada@example.com") }

    before { sign_in_as user }

    it "links the identity to the signed in user, not the account with its email, and says so" do
      link

      identity = ActsAsTenant.with_tenant(tenant) { user.identities.sole }
      expect(identities_of(ada)).to be_empty
      expect(response).to redirect_to(linked_identity_path(identity))
    end

    context "when the identity is linked to someone else" do
      let_it_be(:identity) { create(:identity, user: ada, uid: "ada-uid") }

      it "goes back to settings" do
        link

        expect(identities_of(user)).to be_empty
        expect(response).to redirect_to(account_security_path)
      end
    end

    context "when the session has ended" do
      before { delete session_path(ActsAsTenant.with_tenant(tenant) { user.sessions.last }) }

      it "asks to sign in again" do
        link

        expect(identities_of(user)).to be_empty
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  it "doesn't link an account with the same email on another tenant" do
    other = create(:user, email: "ada@example.com")

    expect { callback }.to change { users.count }.by(1)

    expect(identities_of(other)).to be_empty
  end
end
