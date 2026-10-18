module TenantHosts
  # Serves system specs from the tenant's subdomain; *.localhost resolves to loopback.
  def use_tenant_host(tenant)
    Capybara.app_host = "http://#{tenant.host}"
  end
end

RSpec.configure do |config|
  config.include TenantHosts, type: :system
  config.after(:each, type: :system) { Capybara.app_host = nil }
end
