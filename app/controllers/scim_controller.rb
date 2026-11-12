# Base for the SCIM 2.0 API at /scim/v2 on a tenant's hosts, which its identity
# providers call to manage its users. A provider authenticates with the bearer
# token generated for it under Settings, and answers are SCIM JSON, errors included.
class ScimController < ActionController::API
  include TenantFromHost
  include ActionController::HttpAuthentication::Token::ControllerMethods

  rescue_from(ActiveRecord::RecordNotFound) { render_error "Not found", status: :not_found }
  rescue_from(Scim::InvalidRequest) { |error| render_error error.message, status: :bad_request, scim_type: error.scim_type }

  before_action :require_tenant
  before_action :authenticate

  private
    attr_reader :identity_provider

    # The bare root domain has no tenant, and so no users
    def require_tenant
      render_error "Not found", status: :not_found unless current_tenant
    end

    # Tokens are tenant-scoped like their providers, so one only works on its own tenant's hosts
    def authenticate
      @identity_provider = authenticate_with_http_token { |token| IdentityProvider.find_by_scim_token(token) }
      render_error "A valid bearer token is required", status: :unauthorized unless identity_provider
    end

    # SCIM clients send application/scim+json, which Rails doesn't parse into params
    def scim_body
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      raise Scim::InvalidRequest.new("The request body isn't JSON", scim_type: "invalidSyntax")
    end

    def render_scim(body, status: :ok, location: nil)
      render json: body, status:, location:, content_type: "application/scim+json"
    end

    def render_error(detail, status:, scim_type: nil)
      render_scim({ schemas: [ Scim::ERROR_SCHEMA ], status: Rack::Utils.status_code(status).to_s, scimType: scim_type, detail: }.compact, status:)
    end
end
