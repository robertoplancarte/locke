class CreateRetiredSubdomains < ActiveRecord::Migration[8.1]
  # Subdomains a tenant moved away from. They redirect to the tenant's current
  # address, so bookmarks and emailed links keep working, and stay reserved for it.
  def change
    create_table :retired_subdomains do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :subdomain, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
