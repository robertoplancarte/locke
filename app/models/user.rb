class User < ApplicationRecord
  acts_as_tenant :tenant

  has_secure_password

  # The tenant's identity provider that owns the account, if any: it keeps the
  # account up to date, and its people can only sign in through it
  belongs_to :managed_by, class_name: "IdentityProvider", optional: true

  # Deterministic, so accounts can still be found by email
  encrypts :email, deterministic: true
  encrypts :otp_secret, :name

  # system follows the device's light or dark setting
  enum :theme, %w[system light dark].index_by(&:itself), prefix: true, validate: true

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :recovery_codes, dependent: :destroy
  has_many :security_keys, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :identities, dependent: :destroy

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates_uniqueness_to_tenant :email
  validates :password, allow_nil: true, length: { minimum: 12 }
  validates :password, not_pwned: { message: "might easily be guessed" }
  validates :name, length: { maximum: 100 }
  validate :time_zone_exists

  normalizes :email, with: -> { _1.strip.downcase }
  normalizes :name, with: -> { _1.squish.presence }

  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  def display_name = name || email

  # Up to two letters for an avatar: from the name's words, or the email's first letter
  def initials = (name ? name.split.map(&:first).values_at(0, -1).uniq.join : email.first).upcase

  def two_factor_enabled? = otp_required_for_sign_in?

  def active? = deactivated_at.nil?

  # Already-enrolled users can always manage their setup, even after the tenant turns 2FA off
  def can_set_up_two_factor? = two_factor_enabled? || !tenant.two_factor_off?

  def must_set_up_two_factor? = tenant.two_factor_required? && !two_factor_enabled?

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  before_validation on: :create do
    self.otp_secret = ROTP::Base32.random
  end

  before_validation on: :create do
    self.webauthn_id = WebAuthn.generate_user_id
  end

  # The sub claim apps see: random and permanent, unlike the email
  before_validation on: :create do
    self.public_id ||= "usr_#{SecureRandom.base58(24)}"
  end

  after_update if: :email_previously_changed? do
    events.create! action: "email_verification_requested"
  end

  after_update if: :password_digest_previously_changed? do
    events.create! action: "password_changed"
  end

  after_update if: [ :verified_previously_changed?, :verified? ] do
    events.create! action: "email_verified"
  end

  # Changing the password logs out every other session, its apps included
  # (Session#log_out), keeping only the one it was changed from, if any.
  # False with errors when the new password isn't accepted.
  def change_password(attributes, keeping: nil)
    return false unless update(attributes)

    sessions.where.not(id: keeping).find_each(&:log_out)
    true
  end

  # Updates the account as its identity provider says. The provider vouches for
  # the email, so it stays verified even when it changes.
  def update_from_provider(attributes)
    update(attributes) && (verified? || update(verified: true))
  end

  # A deactivated account can't sign in, and its sessions end everywhere, apps included
  def deactivate
    return unless active?

    update!(deactivated_at: Time.current)
    sessions.find_each(&:log_out)
    events.create! action: "deactivated"
  end

  def reactivate
    return if active?

    update!(deactivated_at: nil)
    events.create! action: "reactivated"
  end

  private

  def time_zone_exists
    errors.add(:time_zone, "isn't a time zone we know") unless ActiveSupport::TimeZone[time_zone.to_s]
  end
end
