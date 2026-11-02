class CreateRecoveryCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :recovery_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :code, null: false
      t.boolean :used, null: false, default: false

      t.timestamps
    end
  end
end
