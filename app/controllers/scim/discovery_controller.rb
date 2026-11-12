# What the SCIM API supports, for clients that ask before they provision
class Scim::DiscoveryController < ScimController
  def service_provider_config
    render_scim({ schemas: [ "urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig" ],
      patch: { supported: true }, bulk: { supported: false, maxOperations: 0, maxPayloadSize: 0 },
      filter: { supported: true, maxResults: Scim::UsersController::MAX_RESULTS },
      changePassword: { supported: false }, sort: { supported: false }, etag: { supported: false },
      authenticationSchemes: [ { type: "oauthbearertoken", name: "Bearer token", primary: true,
        description: "The token generated for the identity provider under Settings" } ] })
  end

  def resource_types
    render_scim({ schemas: [ Scim::LIST_SCHEMA ], totalResults: 1, Resources: [
      { schemas: [ "urn:ietf:params:scim:schemas:core:2.0:ResourceType" ], id: "User", name: "User",
        endpoint: "/Users", schema: Scim::USER_SCHEMA, meta: { resourceType: "ResourceType" } }
    ] })
  end
end
