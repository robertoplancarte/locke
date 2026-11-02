# The provider a tenant's sign-in page sends people to straight away. Null means
# Locke's own sign-in form; deleting the provider falls back to it.
class AddDefaultIdentityProviderToTenants < ActiveRecord::Migration[8.1]
  def change
    add_reference :tenants, :default_identity_provider, foreign_key: { to_table: :identity_providers, on_delete: :nullify }
  end
end
