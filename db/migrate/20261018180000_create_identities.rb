class CreateIdentities < ActiveRecord::Migration[8.1]
  # Users can sign in with several providers, so each provider account gets its own row.
  # The tenant is stored too, so the same provider account can sign up separately on each tenant.
  def up
    create_table :identities do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false

      t.timestamps

      t.index [ :tenant_id, :provider, :uid ], unique: true
    end

    execute <<~SQL
      INSERT INTO identities (tenant_id, user_id, provider, uid, created_at, updated_at)
      SELECT tenant_id, id, provider, uid, created_at, updated_at FROM users WHERE provider IS NOT NULL
    SQL

    change_table :users, bulk: true do |t|
      t.remove_index [ :tenant_id, :provider, :uid ]
      t.remove :provider, :uid
    end
  end

  # Users only had room for one provider, so this keeps their earliest identity
  def down
    change_table :users, bulk: true do |t|
      t.string :provider
      t.string :uid
      t.index [ :tenant_id, :provider, :uid ], unique: true, where: "provider IS NOT NULL"
    end

    execute <<~SQL
      UPDATE users SET provider = identities.provider, uid = identities.uid
      FROM (SELECT DISTINCT ON (user_id) * FROM identities ORDER BY user_id, id) AS identities
      WHERE identities.user_id = users.id
    SQL

    drop_table :identities
  end
end
