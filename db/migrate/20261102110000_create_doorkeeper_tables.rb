# Locke as an OAuth 2.0 / OpenID Connect provider (Doorkeeper).
#
# Applications either belong to one tenant or, with a null tenant_id, are global:
# usable on every tenant's host. Grants and tokens always belong to the tenant
# they were issued on, so a code or token from one tenant is useless on another.
# Both also remember the Locke session they came from, for auth_time, amr and
# (later) logging apps out when that session ends.
class CreateDoorkeeperTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications do |t|
      t.references :tenant, foreign_key: true
      t.string  :name,         null: false
      t.string  :uid,          null: false
      t.string  :secret,       null: false
      t.text    :redirect_uri, null: false
      t.string  :scopes,       null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.timestamps
    end
    add_index :oauth_applications, :uid, unique: true

    create_table :oauth_access_grants do |t|
      t.references :tenant,         null: false, foreign_key: true
      t.references :resource_owner, null: false, foreign_key: { to_table: :users }
      t.references :application,    null: false, foreign_key: { to_table: :oauth_applications }
      t.references :session,        foreign_key: { on_delete: :nullify }
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.string   :scopes,            null: false, default: ""
      t.string   :code_challenge
      t.string   :code_challenge_method
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
    end
    add_index :oauth_access_grants, :token, unique: true

    create_table :oauth_access_tokens do |t|
      t.references :tenant,         null: false, foreign_key: true
      t.references :resource_owner, foreign_key: { to_table: :users }
      t.references :application,    null: false, foreign_key: { to_table: :oauth_applications }
      t.references :session,        foreign_key: { on_delete: :nullify }
      t.string   :token,                  null: false
      t.string   :refresh_token
      t.integer  :expires_in
      t.string   :scopes
      t.datetime :created_at,             null: false
      t.datetime :revoked_at
      # Refresh tokens are revoked once the access token they produced is used
      t.string   :previous_refresh_token, null: false, default: ""
    end
    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true

    create_table :oauth_openid_requests do |t|
      t.references :access_grant, null: false, foreign_key: { to_table: :oauth_access_grants, on_delete: :cascade }
      t.string :nonce, null: false
    end
  end
end
