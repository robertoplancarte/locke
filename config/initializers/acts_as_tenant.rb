ActsAsTenant.configure do |config|
  # Raise ActsAsTenant::Errors::NoTenantSet when a tenant-scoped model is
  # queried without a current tenant, so data can't leak across tenants.
  config.require_tenant = true
end
