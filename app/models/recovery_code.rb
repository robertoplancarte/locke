# A one-time code that stands in for the second factor. Only a keyed digest is
# stored, so a code can be shown once, when it's generated, and never again.
class RecoveryCode < ApplicationRecord
  COUNT = 10

  belongs_to :user

  scope :unused, -> { where(used: false) }

  # Only set on a code generated in this request
  attr_reader :code

  # Replaces the user's codes, returning the new ones to show them
  def self.regenerate_for(user)
    transaction do
      user.recovery_codes.delete_all
      Array.new(COUNT) { user.recovery_codes.create!(code: SecureRandom.alphanumeric(10).downcase).code }
    end
  end

  # Uses up a matching unused code; true if there was one. A single update, so
  # two requests racing with the same code can't both succeed.
  def self.redeem(code)
    unused.where(code_digest: digest(code)).update_all(used: true, updated_at: Time.current) == 1
  end

  # Keyed, so a leaked database can't be brute-forced without the app's secret
  def self.digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("recovery_code"), code.to_s.strip.downcase)
  end

  def code=(value)
    @code = value
    self.code_digest = self.class.digest(value)
  end
end
