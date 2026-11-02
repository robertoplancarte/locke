# A subdomain a tenant moved away from; it redirects to the tenant's current address
class RetiredSubdomain < ApplicationRecord
  belongs_to :tenant
end
