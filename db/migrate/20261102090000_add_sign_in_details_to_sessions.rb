# How and when a session's user proved who they are. An OIDC provider reports
# these as auth_time and amr, and needs them to honor max_age and prompt=login.
class AddSignInDetailsToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :authenticated_at, :datetime
    # RFC 8176 authentication method references, like ["pwd", "otp", "mfa"]
    add_column :sessions, :amr, :string, array: true, default: [], null: false
    add_reference :sessions, :identity_provider, foreign_key: { on_delete: :nullify }

    # Existing sessions were signed in when they were created; how is unknown
    up_only { execute "UPDATE sessions SET authenticated_at = created_at" }
    change_column_null :sessions, :authenticated_at, false
  end
end
