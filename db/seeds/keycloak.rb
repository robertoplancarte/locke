# Identity providers for the development tenants, from a local Keycloak with a
# realm per tenant: Acme signs in over OpenID Connect, Globex over SAML. Locke is
# registered as a client in each realm through Keycloak's admin API, as the
# redirect URLs and SAML entity IDs carry the provider's id. Run again after
# resetting either side; it updates what's already there.
#
# Needs KEYCLOAK_URL, KEYCLOAK_ADMIN_USERNAME and KEYCLOAK_ADMIN_PASSWORD; the
# Keycloak users all have the password "password".
keycloak_url = ENV.fetch("KEYCLOAK_URL")

admin_token = Net::HTTP.post_form(
  URI("#{keycloak_url}/realms/master/protocol/openid-connect/token"),
  grant_type: "password", client_id: "admin-cli",
  username: ENV.fetch("KEYCLOAK_ADMIN_USERNAME"), password: ENV.fetch("KEYCLOAK_ADMIN_PASSWORD")
).then { JSON.parse(it.body).fetch("access_token") }

# Keycloak's admin REST API, at a path under /admin/realms
keycloak = lambda do |method, path, body = nil|
  uri = URI("#{keycloak_url}/admin/#{path.start_with?("/") ? path.delete_prefix("/") : "realms/#{path}"}")
  request = Net::HTTP.const_get(method.to_s.capitalize).new(uri, "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json")
  request.body = body.to_json if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { it.request(request) }
  raise "Keycloak #{method.upcase} #{path}: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body) if response.body.present?
end

# Creates the client, or brings an existing one up to date
upsert_client = lambda do |realm, client|
  if (existing = keycloak.(:get, "#{realm}/clients?clientId=#{CGI.escape(client[:clientId])}").first)
    keycloak.(:put, "#{realm}/clients/#{existing["id"]}", existing.merge(client.deep_stringify_keys))
  else
    keycloak.(:post, "#{realm}/clients", client)
  end
end

# Every address the tenant is reached at through Caddy
base_urls = ->(tenant) { [ tenant.host, *tenant.domains.active.pluck(:hostname) ].map { "http://#{it}" } }

# Points the realm's SCIM provisioning at locke, with a new token for the provider,
# so Keycloak adds, updates and deactivates the tenant's users as its own change.
# Needs the keycloak-scim-outbound extension (ude's dockerfiles/keycloak).
scim_outbound = "keycloak-scim-outbound"
scim_outbound_installed = keycloak.(:get, "/serverinfo").dig("componentTypes", "org.keycloak.storage.UserStorageProvider").to_a.any? { it["id"] == scim_outbound }
warn "Keycloak doesn't have #{scim_outbound}, so its realms won't provision users in locke" unless scim_outbound_installed

provision_users = lambda do |realm, provider, tenant|
  next unless scim_outbound_installed

  events = keycloak.(:get, "#{realm}/events/config")
  keycloak.(:put, "#{realm}/events/config", events.merge("eventsListeners" => events["eventsListeners"] | [ scim_outbound ]))

  component = {
    name: "Locke", providerId: scim_outbound, providerType: "org.keycloak.storage.UserStorageProvider",
    parentId: keycloak.(:get, realm)["id"],
    config: {
      # The custom domain: Keycloak's container reaches it through Caddy, like the browser
      baseUrl: [ "#{base_urls.(tenant).last}/scim/v2" ], token: [ provider.generate_scim_token ],
      userNameStrategy: [ "email" ], deprovisionAction: [ "deactivate" ], syncGroups: [ "false" ], enabled: [ "true" ]
    }
  }
  if (existing = keycloak.(:get, "#{realm}/components?type=org.keycloak.storage.UserStorageProvider&name=Locke").first)
    keycloak.(:put, "#{realm}/components/#{existing["id"]}", existing.merge(component.deep_stringify_keys))
  else
    keycloak.(:post, "#{realm}/components", component)
  end
end

acme = Tenant.find_by!(subdomain: "acme")
ActsAsTenant.with_tenant(acme) do
  client_secret = "locke-development-secret"
  provider = IdentityProvider.find_or_initialize_by(name: "Keycloak")
  provider.update!(protocol: :oidc, enabled: true, issuer: "#{keycloak_url}/realms/acme", client_id: "locke", client_secret:)

  upsert_client.("acme", {
    clientId: "locke", name: "Locke", protocol: "openid-connect", publicClient: false, secret: client_secret,
    standardFlowEnabled: true, directAccessGrantsEnabled: false,
    redirectUris: base_urls.(acme).map { provider.redirect_url(it) }
  })
  provision_users.("acme", provider, acme)
end

globex = Tenant.find_by!(subdomain: "globex")
ActsAsTenant.with_tenant(globex) do
  signing_key = keycloak.(:get, "globex/keys").fetch("keys").find { it["algorithm"] == "RS256" && it["use"] == "SIG" }
  certificate = OpenSSL::X509::Certificate.new(Base64.decode64(signing_key.fetch("certificate"))).to_pem

  provider = IdentityProvider.find_or_initialize_by(name: "Keycloak")
  provider.update!(protocol: :saml, enabled: true, idp_entity_id: "#{keycloak_url}/realms/globex",
    idp_sso_url: "#{keycloak_url}/realms/globex/protocol/saml", idp_certificate: certificate)

  # Locke's SAML entity ID is its metadata URL on the requested host, so one client per address
  base_urls.(globex).each do |base_url|
    upsert_client.("globex", {
      clientId: provider.saml_metadata_url(base_url), name: "Locke (#{URI(base_url).host})", protocol: "saml",
      redirectUris: [ provider.redirect_url(base_url) ],
      attributes: {
        saml_assertion_consumer_url_post: provider.redirect_url(base_url),
        saml_force_name_id_format: "true", saml_name_id_format: "email",
        # Locke doesn't sign its requests; Keycloak signs its responses
        "saml.client.signature": "false", "saml.server.signature": "true"
      },
      protocolMappers: [ {
        name: "email", protocol: "saml", protocolMapper: "saml-user-property-mapper",
        config: { "user.attribute": "email", "attribute.name": "email", "attribute.nameformat": "Basic" }
      } ]
    })
  end
  provision_users.("globex", provider, globex)
end
