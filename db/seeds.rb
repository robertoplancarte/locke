# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Reachable in development at http://acme.localhost:3000
Tenant.find_or_create_by!(subdomain: "acme") do |tenant|
  tenant.name = "Acme Corp"
  tenant.primary_color = "#DC2626"
  tenant.secondary_color = "#111827"
end

# Reachable in development at http://globex.localhost:3000
Tenant.find_or_create_by!(subdomain: "globex") do |tenant|
  tenant.name = "Globex"
  tenant.primary_color = "#16A34A"
  tenant.secondary_color = "#14532D"
end

# Development users, all with the password "password". It fails the length and
# breached-password validations, so they're saved without validation; that skips
# the before_validation callbacks too, so the OTP secret and WebAuthn ID are set here.
# alice@example.com exists on both tenants as two separate accounts.
if Rails.env.development?
  {
    "acme" => %w[alice@example.com bob@example.com],
    "globex" => %w[alice@example.com carol@example.com]
  }.each do |subdomain, emails|
    tenant = Tenant.find_by!(subdomain:)

    ActsAsTenant.with_tenant(tenant) do
      emails.each do |email|
        next if User.exists?(email:)

        User.new(
          email:,
          password: "password",
          verified: true,
          otp_secret: ROTP::Base32.random,
          webauthn_id: WebAuthn.generate_user_id
        ).save!(validate: false)
      end
    end
  end
end
