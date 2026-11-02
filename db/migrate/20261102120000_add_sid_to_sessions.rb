# The sid claim apps see in ID tokens and logout tokens: random, unlike the id
class AddSidToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :sid, :string
    execute "UPDATE sessions SET sid = 'ses_' || md5(random()::text || id::text) WHERE sid IS NULL"
    change_column_null :sessions, :sid, false
    add_index :sessions, :sid, unique: true
  end

  def down
    remove_column :sessions, :sid
  end
end
