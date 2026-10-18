module ApplicationHelper
  # Overrides the default brand CSS variables (app/assets/tailwind/application.css)
  # with the current tenant's colors. Values are validated hex colors.
  def tenant_brand_style_tag(tenant = current_tenant)
    return if tenant.nil?

    variables = {
      "--brand-primary" => tenant.primary_brand_color,
      "--brand-primary-foreground" => tenant.primary_brand_color.foreground,
      "--brand-secondary" => tenant.secondary_brand_color,
      "--brand-secondary-foreground" => tenant.secondary_brand_color.foreground
    }

    tag.style(":root { #{variables.map { |name, value| "#{name}: #{value};" }.join(" ")} }", nonce: content_security_policy_nonce)
  end
end
