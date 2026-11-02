class CreateIdentityProviders < ActiveRecord::Migration[8.1]
  # OIDC and SAML providers a tenant registers so its people can sign in with their
  # own identity provider (Okta, Entra ID, Google Workspace...).
  def change
    create_table :identity_providers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :protocol, null: false
      t.boolean :enabled, default: false, null: false

      # OIDC
      t.string :issuer
      t.string :client_id
      t.text :client_secret

      # SAML
      t.string :idp_entity_id
      t.string :idp_sso_url
      t.text :idp_certificate

      t.timestamps
    end

    # Two providers can hand out the same uid (SAML NameIDs are often emails), so
    # identities from registered providers are unique per provider
    change_table :identities, bulk: true do |t|
      t.references :identity_provider, foreign_key: true
      t.remove_index [ :tenant_id, :provider, :uid ], unique: true
      t.index [ :tenant_id, :provider, :identity_provider_id, :uid ], unique: true, nulls_not_distinct: true,
        name: "index_identities_on_tenant_provider_and_uid"
    end
  end
end
