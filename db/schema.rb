# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_02_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "identities", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "identity_provider_id"
    t.string "email"
    t.index ["identity_provider_id"], name: "index_identities_on_identity_provider_id"
    t.index ["tenant_id", "provider", "identity_provider_id", "uid"], name: "index_identities_on_tenant_provider_and_uid", unique: true, nulls_not_distinct: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "identity_providers", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "protocol", null: false
    t.boolean "enabled", default: false, null: false
    t.string "issuer"
    t.string "client_id"
    t.text "client_secret"
    t.string "idp_entity_id"
    t.string "idp_sso_url"
    t.text "idp_certificate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "creates_users", default: true, null: false
    t.index ["tenant_id"], name: "index_identity_providers_on_tenant_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.bigint "session_id"
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["session_id"], name: "index_oauth_access_grants_on_session_id"
    t.index ["tenant_id"], name: "index_oauth_access_grants_on_tenant_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.bigint "session_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["session_id"], name: "index_oauth_access_tokens_on_session_id"
    t.index ["tenant_id"], name: "index_oauth_access_tokens_on_tenant_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.bigint "tenant_id"
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "backchannel_logout_uri"
    t.string "post_logout_redirect_uris", default: [], null: false, array: true
    t.index ["tenant_id"], name: "index_oauth_applications_on_tenant_id"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "oauth_openid_requests", force: :cascade do |t|
    t.bigint "access_grant_id", null: false
    t.string "nonce", null: false
    t.index ["access_grant_id"], name: "index_oauth_openid_requests_on_access_grant_id"
  end

  create_table "recovery_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.boolean "used", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code_digest", null: false
    t.index ["user_id"], name: "index_recovery_codes_on_user_id"
  end

  create_table "retired_subdomains", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "subdomain", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_retired_subdomains_on_subdomain", unique: true
    t.index ["tenant_id"], name: "index_retired_subdomains_on_tenant_id"
  end

  create_table "security_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "external_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.index ["external_id"], name: "index_security_keys_on_external_id", unique: true
    t.index ["user_id"], name: "index_security_keys_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "sudo_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "authenticated_at", null: false
    t.string "amr", default: [], null: false, array: true
    t.bigint "identity_provider_id"
    t.string "sid", null: false
    t.index ["identity_provider_id"], name: "index_sessions_on_identity_provider_id"
    t.index ["sid"], name: "index_sessions_on_sid", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sign_in_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sign_in_tokens_on_user_id"
  end

  create_table "signing_keys", force: :cascade do |t|
    t.text "private_key", null: false
    t.datetime "retired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tenant_domains", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "hostname", null: false
    t.string "status", default: "pending", null: false
    t.string "cloudflare_id"
    t.string "hostname_status"
    t.string "ssl_status"
    t.jsonb "ownership_verification", default: {}, null: false
    t.jsonb "verification_errors", default: [], null: false
    t.datetime "verified_at"
    t.datetime "last_checked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cloudflare_id"], name: "index_tenant_domains_on_cloudflare_id", unique: true
    t.index ["hostname"], name: "index_tenant_domains_on_hostname", unique: true
    t.index ["status"], name: "index_tenant_domains_on_status"
    t.index ["tenant_id"], name: "index_tenant_domains_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "domain"
    t.string "primary_color", default: "#4F46E5", null: false
    t.string "secondary_color", default: "#0F172A", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "sign_up_enabled", default: true, null: false
    t.boolean "sign_in_links_enabled", default: true, null: false
    t.boolean "social_sign_in_enabled", default: true, null: false
    t.string "two_factor", default: "optional", null: false
    t.bigint "default_identity_provider_id"
    t.index ["default_identity_provider_id"], name: "index_tenants_on_default_identity_provider_id"
    t.index ["domain"], name: "index_tenants_on_domain", unique: true, where: "(domain IS NOT NULL)"
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "verified", default: false, null: false
    t.boolean "otp_required_for_sign_in", default: false, null: false
    t.string "otp_secret", null: false
    t.string "webauthn_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "time_zone", default: "Etc/UTC", null: false
    t.string "theme", default: "system", null: false
    t.string "public_id", null: false
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["tenant_id", "email"], name: "index_users_on_tenant_id_and_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "events", "users"
  add_foreign_key "identities", "identity_providers"
  add_foreign_key "identities", "tenants"
  add_foreign_key "identities", "users"
  add_foreign_key "identity_providers", "tenants"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "sessions", on_delete: :nullify
  add_foreign_key "oauth_access_grants", "tenants"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "sessions", on_delete: :nullify
  add_foreign_key "oauth_access_tokens", "tenants"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "oauth_applications", "tenants"
  add_foreign_key "oauth_openid_requests", "oauth_access_grants", column: "access_grant_id", on_delete: :cascade
  add_foreign_key "recovery_codes", "users"
  add_foreign_key "retired_subdomains", "tenants"
  add_foreign_key "security_keys", "users"
  add_foreign_key "sessions", "identity_providers", on_delete: :nullify
  add_foreign_key "sessions", "users"
  add_foreign_key "sign_in_tokens", "users"
  add_foreign_key "tenant_domains", "tenants"
  add_foreign_key "tenants", "identity_providers", column: "default_identity_provider_id", on_delete: :nullify
  add_foreign_key "users", "tenants"
end
