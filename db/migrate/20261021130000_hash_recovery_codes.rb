class HashRecoveryCodes < ActiveRecord::Migration[8.1]
  # Recovery codes skip two-factor authentication, so only a keyed digest of
  # each is stored. The existing plaintext codes are dropped; users generate new ones.
  def change
    reversible { |direction| direction.up { execute "DELETE FROM recovery_codes" } }

    change_table :recovery_codes, bulk: true do |t|
      t.remove :code, type: :string, null: false
      t.string :code_digest, null: false
    end
  end
end
