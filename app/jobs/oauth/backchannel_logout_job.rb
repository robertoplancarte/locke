module Oauth
  # Tells one app that a Locke session ended. Takes the app's id rather than the
  # app, as an app only loads inside its tenant.
  class BackchannelLogoutJob < ApplicationJob
    retry_on BackchannelLogoutClient::Error, wait: :polynomially_longer, attempts: 5
    discard_on BackchannelLogoutClient::Rejected, ActiveRecord::RecordNotFound, ActiveJob::DeserializationError

    def perform(tenant, application_id, sub:, sid:)
      ActsAsTenant.with_tenant(tenant) do
        OauthApplication.find(application_id).log_out!(tenant, sub:, sid:)
      end
    end
  end
end
