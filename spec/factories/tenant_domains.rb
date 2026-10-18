FactoryBot.define do
  factory :tenant_domain do
    tenant
    sequence(:hostname) { |n| "portal#{n}.customer.com" }

    trait :active do
      status { "active" }
      sequence(:cloudflare_id) { |n| "cf-#{n}" }
      verified_at { 1.day.ago }
      last_checked_at { 1.hour.ago }
    end
  end
end
