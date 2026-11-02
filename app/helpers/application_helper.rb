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

  # The tenant's favicon (or logo) resized for browser tabs and home screens,
  # or Locke's own icons (public/icon.*) when there's no tenant or it has neither
  def favicon_link_tags(tenant = current_tenant)
    if (image = tenant&.icon_image)
      safe_join([
        tag.link(rel: "icon", href: url_for(image.variant(:favicon)), type: "image/png", sizes: "32x32"),
        tag.link(rel: "apple-touch-icon", href: url_for(image.variant(:apple_touch_icon)), sizes: "180x180")
      ], "\n")
    else
      safe_join([
        tag.link(rel: "icon", href: "/icon.png", type: "image/png"),
        tag.link(rel: "icon", href: "/icon.svg", type: "image/svg+xml"),
        tag.link(rel: "apple-touch-icon", href: "/icon.png")
      ], "\n")
    end
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
