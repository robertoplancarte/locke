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

  it "signs in to a tenant" do
    user = create(:user, tenant:, email: "ada@example.com")
    visit "/sign_in"

    expect(page).to have_css("h2", text: "Sign in to Acme")
    fill_in "Email address", with: user.email
    fill_in "Password", with: "correct horse battery"
    click_on "Sign in"

    expect(page).to have_text("Signed in successfully")
  end

  it "signs in with a link emailed from the sign in form" do
    create(:user, tenant:, email: "ada@example.com")
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
    create(:user, tenant:, email: "ada@example.com")
    visit "/sign_in"

    fill_in "Email address", with: "ada@example.com"
    fill_in("Password", with: "correct horse battery").send_keys(:enter)

    expect(page).to have_text("Signed in successfully")
  end

  it "keeps the email when the password is wrong" do
    create(:user, tenant:, email: "ada@example.com")
    visit "/sign_in"

    fill_in "Email address", with: "ada@example.com"
    fill_in "Password", with: "not the password"
    click_on "Sign in"

    expect(page).to have_text("That email or password is incorrect")
    expect(page).to have_field("Email address", with: "ada@example.com")
  end
end
