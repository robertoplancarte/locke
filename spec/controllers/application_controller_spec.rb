require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      render plain: ActsAsTenant.current_tenant&.subdomain.to_s
    end
  end

  let!(:tenant) { create(:tenant, subdomain: "acme") }

  it "sets the tenant resolved from the request host" do
    request.host = "acme.localhost"
    get :index

    expect(response.body).to eq("acme")
  end

  it "runs without a tenant on the root domain" do
    request.host = "www.localhost"
    get :index

    expect(response.body).to eq("")
  end

  it "responds not found for an unknown tenant host" do
    request.host = "unknown.localhost"

    expect { get :index }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
