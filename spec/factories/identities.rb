FactoryBot.define do
  factory :identity do
    user
    tenant { user.tenant }
    provider { "developer" }
    sequence(:uid) { |n| "uid-#{n}" }

    # Identities are tenant-scoped like their users
    initialize_with { ActsAsTenant.with_tenant(tenant) { new } }
    to_create { |identity| ActsAsTenant.with_tenant(identity.tenant) { identity.save! } }
  end
end
