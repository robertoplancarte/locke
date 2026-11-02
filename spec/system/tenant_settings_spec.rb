require "rails_helper"

RSpec.describe "Tenant settings", type: :system do
  let!(:tenant) { create(:tenant, subdomain: "acme", name: "Acme") }

  let!(:user) { create(:user, tenant:) }

  before do
    use_tenant_host(tenant)
    sign_in_as user
  end

  it "rebrands the workspace" do
    visit "/settings/branding/edit"

    fill_in "Workspace name", with: "Acme Corp"
    find_field("Primary color").set("#16a34a")
    attach_file "Logo", file_fixture("logo.png")
    click_on "Save branding"

    expect(page).to have_text("Branding saved.")
    within("header") { expect(page).to have_text("Acme Corp").and have_css("img") }
    expect(page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--brand-primary').trim()")).to eq("#16A34A")
  end

  it "adds a custom domain and shows how to verify it" do
    visit "/settings/domains"

    fill_in "Domain", with: "Portal.Acme.com"
    click_on "Add domain"

    expect(page).to have_text("portal.acme.com added.")
    within("#tenant_domain_#{tenant.domains.sole.id}") do
      expect(page).to have_text("Waiting for DNS")
      expect(page).to have_css("td", text: "tenants.localhost")
    end
  end

  it "changes the workspace address" do
    visit "/settings/domains"

    fill_in "Subdomain", with: "acme-corp"
    accept_confirm { click_on "Change address" }

    expect(page).to have_current_path(%r{\Ahttp://acme-corp\.localhost:\d+/sign_in\z}, url: true)
    expect(page).to have_button("Sign in")
  end

  it "switches to the dark theme" do
    visit "/account"

    within("#preference_theme") { click_on "Update" }
    choose "Dark"
    click_on "Save"

    expect(page).to have_text("Preferences saved.")
    within("#preference_theme") { expect(page).to have_text("Dark") }
    background = "getComputedStyle(document.body).backgroundColor"
    expect(page.evaluate_script(background)).to start_with("oklch(0.13")
  end

  it "removes a custom domain" do
    create(:tenant_domain, :active, tenant:, hostname: "portal.acme.com")
    visit "/settings/domains"

    accept_confirm { click_on "Remove" }

    expect(page).to have_text("portal.acme.com is being removed.")
    expect(page).to have_text("Removing")
  end

  it "registers an app and shows its secret once" do
    visit "/settings/branding/edit"
    within("header") { click_on "Apps" }
    click_on "Register an app"

    fill_in "Name", with: "Intranet"
    fill_in "Redirect URIs", with: "https://intranet.acme.com/callback"
    click_on "Register app"

    expect(page).to have_text("Intranet registered.")
    expect(page).to have_css("#client_secret")

    visit current_path
    expect(page).to have_no_css("#client_secret")
    expect(page).to have_button("Generate new secret")
  end
end
