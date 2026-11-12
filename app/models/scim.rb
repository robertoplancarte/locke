# SCIM 2.0 (RFC 7643, RFC 7644): how a tenant's identity provider creates,
# updates and deactivates its users here. See Scim::UsersController.
module Scim
  USER_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:User".freeze
  LIST_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:ListResponse".freeze
  ERROR_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:Error".freeze

  # A request Locke can't make sense of, answered with a 400 and its scimType
  class InvalidRequest < StandardError
    attr_reader :scim_type

    def initialize(message, scim_type: "invalidValue")
      super(message)
      @scim_type = scim_type
    end
  end
end
