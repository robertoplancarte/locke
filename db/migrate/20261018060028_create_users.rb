class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.string :email,           null: false
      t.string :password_digest, null: false

      t.boolean :verified, null: false, default: false

      t.boolean :otp_required_for_sign_in, null: false, default: false
      t.string  :otp_secret, null: false

      t.string :webauthn_id, null: false

      t.string :provider
      t.string :uid

      t.timestamps

      # The same email can sign up separately on each tenant
      t.index [:tenant_id, :email], unique: true
      t.index [:tenant_id, :provider, :uid], unique: true, where: "provider IS NOT NULL"
    end
  end
end
