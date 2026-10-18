class AddAuthenticationSettingsToTenants < ActiveRecord::Migration[8.1]
  def change
    change_table :tenants, bulk: true do |t|
      t.boolean :sign_up_enabled, null: false, default: true
      t.boolean :sign_in_links_enabled, null: false, default: true
      t.boolean :social_sign_in_enabled, null: false, default: true
      t.string :two_factor, null: false, default: "optional"
    end
  end
end
