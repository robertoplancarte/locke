require "rails_helper"

RSpec.describe "Development: tenant directory", type: :request do
  let_it_be(:tenant) { create(:tenant, subdomain: "acme", name: "Acme") }
  let_it_be(:active_domain) { create(:tenant_domain, :active, tenant:, hostname: "portal.acme.com") }
  let_it_be(:pending_domain) { create(:tenant_domain, tenant:, hostname: "pending.acme.com") }

  it "links to every tenant's workspace from the root domain" do
    host! "localhost"
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="http://acme.localhost/"', "portal.acme.com")
    expect(response.body).not_to include("pending.acme.com")
  end
end
