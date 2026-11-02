FactoryBot.define do
  # A global app unless given a tenant
  factory :oauth_application do
    tenant { nil }
    sequence(:name) { |n| "App #{n}" }
    redirect_uri { "https://app.example.com/callback" }

    initialize_with { ActsAsTenant.without_tenant { new } }
    to_create { |app| ActsAsTenant.without_tenant { app.save! } }

    trait :backchannel_logout do
      backchannel_logout_uri { "https://app.example.com/backchannel_logout" }
    end
  end

  # Tokens and grants belong to the tenant they were issued on, the session's user's
  factory :oauth_access_token do
    session
    tenant { session.user.tenant }
    application factory: :oauth_application
    resource_owner_id { session.user_id }
    scopes { "openid" }
    expires_in { 15.minutes.to_i }
    use_refresh_token { true }

    initialize_with { ActsAsTenant.with_tenant(tenant) { new } }
    to_create { |token| ActsAsTenant.with_tenant(token.tenant) { token.save! } }
  end

  factory :oauth_access_grant do
    session
    tenant { session.user.tenant }
    application factory: :oauth_application
    resource_owner_id { session.user_id }
    redirect_uri { application.redirect_uri }
    scopes { "openid" }
    expires_in { 5.minutes.to_i }

    initialize_with { ActsAsTenant.with_tenant(tenant) { new } }
    to_create { |grant| ActsAsTenant.with_tenant(grant.tenant) { grant.save! } }
  end

  factory :session do
    user
  end
end
