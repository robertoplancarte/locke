# An app that signs people in with Locke over OpenID Connect.
#
# A tenant's own app (tenant_id set) only works on that tenant's hosts. A global
# app (no tenant) works on every tenant's host: the first-party apps. Either
# way, its grants and tokens belong to the tenant they were issued on, and the
# uid (client_id) is unique across all of them, so no tenant can shadow a
# global app.
class OauthApplication < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

  acts_as_tenant :tenant, has_global_records: true, optional: true

  def global? = tenant_id.nil?
end
