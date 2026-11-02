require "rails_helper"

RSpec.describe "Authentication", type: :system do
  let!(:tenant) { create(:tenant, subdomain: "acme", name: "Acme") }

  before { use_tenant_host(tenant) }

  it "signs up for a tenant" do
    visit "/sign_up"

    expect(page).to have_css("h2", text: "Create your Acme account")
    fill_in "Email address", with: "ada@example.com"
    fill_in "Password", with: "correct horse battery"
    fill_in "Confirm password", with: "correct horse battery"
    click_on "Sign up"

    expect(page).to have_text("Welcome! You have signed up successfully")
    expect(page).to have_text("Welcome, ada@example.com")
  end

  context "with an account" do
    let!(:ada) { create(:user, tenant:, email: "ada@example.com") }

    it "signs in to a tenant" do
      visit "/sign_in"

      expect(page).to have_css("h2", text: "Sign in to Acme")
      fill_in "Email address", with: ada.email
      fill_in "Password", with: "correct horse battery"
      click_on "Sign in"

      expect(page).to have_text("Signed in successfully")
    end

    context "with a default identity provider" do
      let!(:okta) { create(:identity_provider, tenant:, name: "Okta") }

      before do
        tenant.update!(default_identity_provider: okta)
        OmniAuth.config.test_mode = true
        OmniAuth.config.mock_auth[:oidc] = OmniAuth::AuthHash.new(provider: "oidc", uid: "ada-sub", info: { email: "ada@example.com", email_verified: true })
      end

      after do
        OmniAuth.config.mock_auth.delete(:oidc)
        OmniAuth.config.test_mode = false
      end

      it "goes straight through the provider and back to the page that asked" do
        visit "/account"

        expect(page).to have_text("Signed in successfully")
        expect(page).to have_current_path("/account")
      end

      it "still offers the sign-in form" do
        visit "/sign_in?local=1"

        fill_in "Email address", with: "ada@example.com"
        fill_in "Password", with: "correct horse battery"
        click_on "Sign in"

        expect(page).to have_text("Signed in successfully")
      end
    end

    it "signs in with a link emailed from the sign in form" do
      visit "/sign_in"

      fill_in "Email address", with: "ada@example.com"
      perform_enqueued_jobs do
        click_on "Email me a sign-in link"
        expect(page).to have_text("Check your email for sign in instructions")
      end

      link = ActionMailer::Base.deliveries.last.body.decoded[%r{http://acme\.localhost/sessions/passwordless/edit\?sid=[^"]+}]
      visit URI(link).request_uri

      expect(page).to have_text("Signed in successfully")
    end

    it "signs in, not emails a link, when pressing Enter" do
      visit "/sign_in"

      fill_in "Email address", with: "ada@example.com"
      fill_in("Password", with: "correct horse battery").send_keys(:enter)

      expect(page).to have_text("Signed in successfully")
    end

    it "keeps the email when the password is wrong" do
      visit "/sign_in"

      fill_in "Email address", with: "ada@example.com"
      fill_in "Password", with: "not the password"
      click_on "Sign in"

      expect(page).to have_text("That email or password is incorrect")
      expect(page).to have_field("Email address", with: "ada@example.com")
    end
  end
end
