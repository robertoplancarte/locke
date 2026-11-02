# A signed-in browser. Apps that sign people in through Locke get tokens tied
# to the session they were approved from, so ending it ends their access too.
class Session < ApplicationRecord
  belongs_to :user
  # The external provider the user signed in with, if any
  belongs_to :identity_provider, optional: true
  # Issued under this session, and revoked when it ends. The database nullifies
  # the link if a session is deleted some other way.
  has_many :oauth_access_grants, dependent: nil
  has_many :oauth_access_tokens, dependent: nil

  encrypts :user_agent, :ip_address

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address

    # The sid claim apps see: random, so it says nothing about other sessions
    self.sid ||= "ses_#{SecureRandom.base58(24)}"
    self.sudo_at = Time.current
    self.authenticated_at ||= Time.current
  end

  after_create  { user.events.create! action: "signed_in" }
  after_destroy { user.events.create! action: "signed_out" }

  def sudo?
    sudo_at > 30.minutes.ago
  end

  # Signing in again in the same browser (an app asked for prompt=login or
  # max_age) refreshes this session instead of replacing it, so apps keep their
  # tokens and the sid they know it by
  def reauthenticate!(amr:, identity_provider:)
    update!(amr:, identity_provider:, authenticated_at: Time.current, sudo_at: Time.current)
    user.events.create! action: "signed_in_again"
  end

  # Ends the session everywhere: its codes and tokens, refresh tokens included,
  # stop working, and apps that take back-channel logout are told to end theirs
  def log_out
    apps = ActsAsTenant.with_tenant(user.tenant) do
      transaction do
        signed_in_apps.to_a.tap do
          oauth_access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)
          oauth_access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
          destroy!
        end
      end
    end

    apps.each { |app| app.log_out_later(user.tenant, sub: user.public_id, sid:) }
  end

  private
    def signed_in_apps
      OauthApplication.where(id: oauth_access_tokens.select(:application_id)).where.not(backchannel_logout_uri: nil)
    end
end
