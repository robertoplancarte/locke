# Whether a tenant's provider can create accounts for people signing in with it
# for the first time. On by default, so existing providers keep working.
class AddCreatesUsersToIdentityProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :identity_providers, :creates_users, :boolean, default: true, null: false
  end
end
