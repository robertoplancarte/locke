class AddPublicKeyToSecurityKeys < ActiveRecord::Migration[8.1]
  # Assertions are verified against the key's public key and sign count, so every key needs both.
  # Keys registered before this can't be verified, so they must be removed and added again.
  def change
    change_table :security_keys, bulk: true do |t|
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
    end
  end
end
