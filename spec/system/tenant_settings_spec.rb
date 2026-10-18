require "rails_helper"

RSpec.describe "Tenant settings", type: :system do
  let!(:tenant) { create(:tenant, subdomain: "acme", name: "Acme") }

  before { use_tenant_host(tenant) }

  it "rebrands the workspace" do
    visit "/"

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

  it "removes a custom domain" do
    create(:tenant_domain, :active, tenant:, hostname: "portal.acme.com")
    visit "/settings/domains"

    accept_confirm { click_on "Remove" }

    expect(page).to have_text("portal.acme.com is being removed.")
    expect(page).to have_text("Removing")
  end
end
