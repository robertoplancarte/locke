require "rails_helper"

# The avatar menu in the top nav. Ending the session (revoking tokens, back-channel
# logout) is Session#log_out's, covered in spec/models/session_spec.rb.
RSpec.describe "Account menu", type: :system do
  let!(:tenant) { create(:tenant, subdomain: "acme", name: "Acme") }
  let!(:ada) { create(:user, tenant:, email: "ada@example.com") }

  before do
    use_tenant_host(tenant)
    sign_in_as(ada)
  end

  it "opens from the avatar and goes to the account page" do
    expect(page).to have_no_link("Your account")

    within("header") { click_on "Your account" }
    within("#account_menu") { click_on "Your account" }

    expect(page).to have_current_path("/account")
  end

  it "closes on Escape and on a click outside it" do
    within("header") { click_on "Your account" }
    expect(page).to have_css("#account_menu", visible: true)

    page.send_keys(:escape)
    expect(page).to have_no_css("#account_menu", visible: true)

    within("header") { click_on "Your account" }
    find("main").click
    expect(page).to have_no_css("#account_menu", visible: true)
  end

  it "logs out" do
    within("header") { click_on "Your account" }
    within("#account_menu") { click_on "Log out" }

    expect(page).to have_text("That session has been logged out")
    visit "/account"
    expect(page).to have_current_path("/sign_in")
  end
end
