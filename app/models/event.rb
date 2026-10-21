class Event < ApplicationRecord
  # How long the security log keeps an event, with the IP address and browser it came from
  RETENTION = 90.days

  belongs_to :user

  encrypts :user_agent, :ip_address

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
