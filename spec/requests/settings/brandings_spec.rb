require "rails_helper"

RSpec.describe "Settings: branding", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme", name: "Acme", primary_color: "#DC2626") }

  let_it_be(:user) { create(:user, tenant:) }

  before do
    host! "acme.localhost"
    sign_in_as user
  end

  describe "GET /settings/branding/edit" do
    it "renders the form in the tenant's brand" do
      get edit_settings_branding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("--brand-primary: #DC2626;")
      expect(response.body).to include('value="Acme"')
    end
  end

  describe "PATCH /settings/branding" do
    subject(:update_branding) { patch settings_branding_path, params: { tenant: attributes } }

    context "with valid attributes" do
      let(:attributes) { { name: "Acme Corp", primary_color: "#16a34a", logo: fixture_file_upload("logo.png", "image/png") } }

      it "saves them" do
        update_branding

        expect(response).to redirect_to(edit_settings_branding_path)
        expect(tenant.reload).to have_attributes(name: "Acme Corp", primary_color: "#16A34A")
        expect(tenant.logo).to be_attached
      end
    end

    context "with invalid attributes" do
      let(:attributes) { { name: "", primary_color: "red; } body { display: none" } }

      it "re-renders the form while keeping the saved brand in the page" do
        update_branding

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("--brand-primary: #DC2626;")
        expect(response.body).not_to include("display: none;")
      end
    end

    context "with a favicon" do
      let(:attributes) { { favicon: fixture_file_upload("square_icon.png", "image/png") } }

      it "saves it" do
        update_branding

        expect(response).to redirect_to(edit_settings_branding_path)
        expect(tenant.reload.favicon).to be_attached
      end
    end

    context "with a non-image favicon" do
      let(:attributes) { { favicon: fixture_file_upload("saml_idp_certificate.pem", "application/x-pem-file") } }

      it "re-renders the form without saving it" do
        update_branding

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Favicon must be a PNG, JPEG or WebP image")
        expect(tenant.reload.favicon).not_to be_attached
      end
    end

    context "when removing the favicon" do
      let(:attributes) { { remove_favicon: "1" } }

      before { tenant.favicon.attach(fixture_file_upload("square_icon.png", "image/png")) }

      it "detaches it" do
        update_branding

        expect(response).to redirect_to(edit_settings_branding_path)
        expect(tenant.reload.favicon).not_to be_attached
      end
    end

    context "when removing the logo" do
      let(:attributes) { { remove_logo: "1" } }

      before { tenant.logo.attach(fixture_file_upload("logo.png", "image/png")) }

      it "detaches it" do
        update_branding

        expect(tenant.reload.logo).not_to be_attached
      end
    end

    it "can't change the subdomain" do
      patch settings_branding_path, params: { tenant: { name: "Acme", subdomain: "evil" } }

      expect(tenant.reload.subdomain).to eq("acme")
    end
  end

  it "isn't available on the root domain" do
    host! "localhost"
    get "/settings/branding/edit"

    expect(response).to have_http_status(:not_found)
  end
end
