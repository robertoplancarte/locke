class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :primary_color, null: false, default: "#4F46E5"
      t.string :secondary_color, null: false, default: "#0F172A"

      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
  end
end
