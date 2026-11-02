class Tenant < ApplicationRecord
  # Subdomains that must never be claimed by a tenant
  RESERVED_SUBDOMAINS = %w[www app api admin assets cdn mail help support status].freeze
  SUBDOMAIN_FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
  HEX_COLOR_FORMAT = /\A#\h{6}\z/
  # No SVG: Active Storage serves it as a download (it can carry scripts), so it wouldn't render
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  LOGO_MAX_SIZE = 2.megabytes

  has_many :domains, class_name: "TenantDomain", dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :identity_providers, dependent: :destroy
  # Only the tenant's own apps; global ones (no tenant) aren't any tenant's to manage
  has_many :oauth_applications, dependent: :destroy
  # Where the sign-in page sends people straight away; nil shows Locke's own form
  belongs_to :default_identity_provider, class_name: "IdentityProvider", optional: true
  has_many :retired_subdomains, dependent: :delete_all
  has_one_attached :logo

  # off: nobody can set up 2FA; optional: users choose; required: users must set it up before using the app.
  # Users who already set it up keep being challenged either way.
  enum :two_factor, { off: "off", optional: "optional", required: "required" }, prefix: true, validate: true

  normalizes :subdomain, with: ->(value) { value.strip.downcase }
  normalizes :primary_color, :secondary_color, with: ->(value) { value.strip.upcase }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true,
    format: { with: SUBDOMAIN_FORMAT, message: "may only contain lowercase letters, numbers and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :primary_color, :secondary_color, format: { with: HEX_COLOR_FORMAT, message: "must be a hex color like #1A2B3C" }
  validate :logo_is_an_acceptable_image
  validate :subdomain_not_retired_by_another_tenant, if: :subdomain_changed?
  validate :default_identity_provider_is_usable, if: :default_identity_provider_id_changed?

  # The old subdomain keeps redirecting here; moving back to an old one makes it current again
  after_update if: :subdomain_previously_changed? do
    retired_subdomains.where(subdomain:).delete_all
    retired_subdomains.create!(subdomain: subdomain_previously_was)
  end

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

  # The tenant whose old subdomain this host is, to redirect to where it lives now
  def self.find_by_retired_host(host, root_domain: Rails.configuration.x.root_domain)
    subdomain = normalize_host(host).delete_suffix(".#{root_domain}")
    joins(:retired_subdomains).find_by(retired_subdomains: { subdomain: }) unless subdomain.include?(".")
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

  # The one address the tenant is known by to apps, as its OpenID Connect issuer:
  # its first verified custom domain if it has one, its subdomain otherwise.
  # The tenant's other addresses redirect the OIDC endpoints here.
  def canonical_host(root_domain: Rails.configuration.x.root_domain)
    domains.active.order(:created_at).pick(:hostname) || host(root_domain:)
  end

  # The tenant's OpenID Connect issuer: its canonical host, reached as configured
  # in config.x.public_url_options, so requests and jobs agree on it
  def oidc_issuer(protocol:, port: nil, root_domain: Rails.configuration.x.root_domain)
    "#{protocol}://#{canonical_host(root_domain:)}#{":#{port}" if port}"
  end

  def primary_brand_color = BrandColor.new(primary_color)
  def secondary_brand_color = BrandColor.new(secondary_color)

  private

  def subdomain_not_retired_by_another_tenant
    errors.add(:subdomain, :taken) if RetiredSubdomain.where(subdomain:).where.not(tenant_id: id).exists?
  end

  # Looked up unscoped by id, so check it's this tenant's own, and that people can sign in with it
  def default_identity_provider_is_usable
    return if default_identity_provider_id.nil?

    provider = ActsAsTenant.without_tenant { IdentityProvider.find_by(id: default_identity_provider_id) }
    errors.add(:default_identity_provider, "must be one of your enabled providers") unless provider&.tenant_id == id && provider.enabled?
  end

  def logo_is_an_acceptable_image
    return unless logo.attached?

    errors.add(:logo, "must be a PNG, JPEG or WebP image") unless logo.content_type.in?(LOGO_CONTENT_TYPES)
    errors.add(:logo, "must be smaller than 2 MB") if logo.byte_size > LOGO_MAX_SIZE
  end
end
