FactoryBot.define do
  factory :identity_provider do
    tenant
    sequence(:name) { |n| "Provider #{n}" }
    protocol { "oidc" }
    enabled { true }
    issuer { "https://idp.example.com" }
    client_id { "client-id" }
    client_secret { "client-secret" }

    trait :saml do
      protocol { "saml" }
      issuer { nil }
      client_id { nil }
      client_secret { nil }
      idp_entity_id { "https://idp.example.com/saml" }
      idp_sso_url { "https://idp.example.com/saml/sso" }
      idp_certificate { Rails.root.join("spec/fixtures/files/saml_idp_certificate.pem").read }
    end

    # Identity providers are tenant-scoped like users
    initialize_with { ActsAsTenant.with_tenant(tenant) { new } }
    to_create { |identity_provider| ActsAsTenant.with_tenant(identity_provider.tenant) { identity_provider.save! } }
  end
end
