# The stable, random identifier apps see as the OIDC sub claim, so they never
# learn (or depend on) the integer primary key
class AddPublicIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :public_id, :string
    up_only { execute "UPDATE users SET public_id = 'usr_' || md5(random()::text || id::text) WHERE public_id IS NULL" }
    change_column_null :users, :public_id, false
    add_index :users, :public_id, unique: true
  end
end
