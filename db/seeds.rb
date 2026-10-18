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
