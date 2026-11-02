# Keys that sign ID tokens. The newest active key signs; the others stay in the
# JWKS until retired, so tokens signed before a rotation still verify.
class CreateSigningKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :signing_keys do |t|
      t.text :private_key, null: false
      t.datetime :retired_at
      t.timestamps
    end
  end
end
