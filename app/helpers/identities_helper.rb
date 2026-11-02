module IdentitiesHelper
  # [name, path] of each provider a signed-in user can link: the tenant's linkable ones,
  # plus the app's from config/initializers/omniauth.rb
  def linkable_identity_providers
    providers = current_tenant.identity_providers.linkable.order(:created_at).map { [ it.name, it.auth_path ] }
    providers << [ "Developer", "/auth/developer" ] if current_tenant.social_sign_in_enabled? && !Rails.env.production?
    providers
  end
end
