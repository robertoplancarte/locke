class CreateTenantDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_domains do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :hostname, null: false
      t.string :status, null: false, default: "pending"

      # Mirrors the Cloudflare for SaaS custom hostname
      t.string :cloudflare_id
      t.string :hostname_status
      t.string :ssl_status
      t.jsonb :ownership_verification, null: false, default: {}
      t.jsonb :verification_errors, null: false, default: []

      t.datetime :verified_at
      t.datetime :last_checked_at
      t.timestamps
    end

    # Cloudflare allows a hostname only once per zone, so it's unique across all tenants
    add_index :tenant_domains, :hostname, unique: true
    add_index :tenant_domains, :cloudflare_id, unique: true
    add_index :tenant_domains, :status
  end
end
