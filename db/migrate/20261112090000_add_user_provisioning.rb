class AddUserProvisioning < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.datetime :deactivated_at
      # The identity provider that owns the account: users it manages can only sign in through it
      t.references :managed_by, foreign_key: { to_table: :identity_providers, on_delete: :nullify }
      # The provider's own id for the user, as SCIM sends it
      t.string :external_id
    end

    add_column :identity_providers, :scim_token_digest, :string
    add_index :identity_providers, :scim_token_digest, unique: true

    create_table :provisioning_issues do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :identity_provider, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :source, null: false
      t.string :message, null: false
      t.jsonb :details, default: {}, null: false
      t.integer :occurrences, default: 1, null: false
      t.datetime :last_occurred_at, null: false
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :provisioning_issues, %i[tenant_id resolved_at]
  end
end
