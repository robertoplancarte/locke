# An RS256 key pair that signs ID tokens. The newest active key signs; older
# active ones stay published in the JWKS so tokens they signed still verify.
# Rotate with `bin/rails oauth:signing_key:rotate`, and retire the old key once
# its tokens have expired.
class SigningKey < ApplicationRecord
  encrypts :private_key

  scope :active, -> { where(retired_at: nil).order(created_at: :desc) }

  def self.generate! = create!(private_key: OpenSSL::PKey::RSA.new(2048).to_pem)

  # PEMs for Doorkeeper::OpenidConnect, signing key first
  def self.pems = active.pluck(:private_key)

  def retire! = touch(:retired_at)
end
