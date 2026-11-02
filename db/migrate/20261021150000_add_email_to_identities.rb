class AddEmailToIdentities < ActiveRecord::Migration[8.1]
  # The provider account's email, so a user can tell two accounts at the same provider apart
  def change
    add_column :identities, :email, :string
  end
end
