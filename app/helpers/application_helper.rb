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

  # The signed-in user's theme; signed-out pages follow the device
  def current_theme = Current.user&.theme || "system"

  # Rails' named zones, one option per IANA identifier (some names share one)
  def time_zone_options
    ActiveSupport::TimeZone.all.group_by { it.tzinfo.name }.map do |identifier, zones|
      [ "(GMT#{zones.first.formatted_offset}) #{zones.map(&:name).join(", ")}", identifier ]
    end
  end

  def time_zone_label(identifier) = time_zone_options.rassoc(identifier)&.first || identifier

  def theme_options = { "system" => "Match my device", "light" => "Light", "dark" => "Dark" }
end
