class CreateSecurityKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :security_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name,        null: false
      t.string :external_id, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
