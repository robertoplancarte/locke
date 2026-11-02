class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :name
      # An IANA identifier, e.g. "America/New_York"
      t.string :time_zone, null: false, default: "Etc/UTC"
      t.string :theme, null: false, default: "system"
    end
  end
end
