FactoryBot.define do
  factory :user do
    tenant
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "correct horse battery" }
    verified { true }

    # Users are tenant-scoped: even building one requires a current tenant
    initialize_with { ActsAsTenant.with_tenant(tenant) { new } }
    to_create { |user| ActsAsTenant.with_tenant(user.tenant) { user.save! } }
  end
end
