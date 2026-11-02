# Where an app hears that a Locke session ended (OIDC Back-Channel Logout), and
# where it may send people after they log out (OIDC RP-Initiated Logout)
class AddLogoutUrisToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :backchannel_logout_uri, :string
    add_column :oauth_applications, :post_logout_redirect_uris, :string, array: true, default: [], null: false
  end
end
