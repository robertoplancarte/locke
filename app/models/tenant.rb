class Tenant < ApplicationRecord
  # Subdomains that must never be claimed by a tenant
  RESERVED_SUBDOMAINS = %w[www app api admin assets cdn mail help support status].freeze
  SUBDOMAIN_FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
  HEX_COLOR_FORMAT = /\A#\h{6}\z/
  # No SVG: Active Storage serves it as a download (it can carry scripts), so it wouldn't render
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  LOGO_MAX_SIZE = 2.megabytes

  has_many :domains, class_name: "TenantDomain", dependent: :restrict_with_error
  has_one_attached :logo

  normalizes :subdomain, with: ->(value) { value.strip.downcase }
  normalizes :primary_color, :secondary_color, with: ->(value) { value.strip.upcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
    format: { with: SUBDOMAIN_FORMAT, message: "may only contain lowercase letters, numbers and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :primary_color, :secondary_color, format: { with: HEX_COLOR_FORMAT, message: "must be a hex color like #1A2B3C" }
  validate :logo_is_an_acceptable_image

  # Resolves the tenant for a request host: hosts under the app's root domain
  # are matched by subdomain, any other host by its active custom domain.
  # Returns nil for the bare root domain (and www), where no tenant applies.
  def self.find_by_host(host, root_domain: Rails.configuration.x.root_domain)
    host = normalize_host(host)
    return if root_host?(host, root_domain:)

    if (subdomain = host.delete_suffix(".#{root_domain}")) != host
      find_by(subdomain:) unless subdomain.include?(".")
    else
      joins(:domains).merge(TenantDomain.active).find_by(tenant_domains: { hostname: host })
    end
  end

  def self.root_host?(host, root_domain: Rails.configuration.x.root_domain)
    normalize_host(host).in?([ root_domain, "www.#{root_domain}" ])
  end

  def self.normalize_host(host) = host.to_s.downcase.delete_suffix(".")
  private_class_method :normalize_host

  # Domains are verified asynchronously; the returned domain carries any validation errors.
  def claim_domain(hostname)
    domains.create(hostname:).tap do |domain|
      domain.sync_later if domain.persisted?
    end
  end

  # The tenant's address under the app's root domain, e.g. acme.yourapp.com
  def host(root_domain: Rails.configuration.x.root_domain) = "#{subdomain}.#{root_domain}"

  def primary_brand_color = BrandColor.new(primary_color)
  def secondary_brand_color = BrandColor.new(secondary_color)

  private

  def logo_is_an_acceptable_image
    return unless logo.attached?

    errors.add(:logo, "must be a PNG, JPEG or WebP image") unless logo.content_type.in?(LOGO_CONTENT_TYPES)
    errors.add(:logo, "must be smaller than 2 MB") if logo.byte_size > LOGO_MAX_SIZE
  end
end
