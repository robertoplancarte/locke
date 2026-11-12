# What a SCIM client asks to change about a user, as attributes for
# UserProvisioning: from a whole User resource (POST and PUT), or from a PatchOp
# applied to the user as they are (PATCH).
#
# SCIM attribute names are case-insensitive, so they're compared downcased.
# Attributes Locke doesn't keep, like phone numbers or the enterprise extension,
# are ignored. Locke has one email, the primary one (or the first), and the
# userName stands in for it when there's none.
class Scim::UserChanges
  def self.from_resource(resource)
    raise Scim::InvalidRequest.new("The request body must be a SCIM User", scim_type: "invalidSyntax") unless resource.is_a?(Hash)

    new.tap { it.merge_value(nil, resource) }.attributes
  end

  def self.from_patch(body, user)
    operations = body["Operations"] if body.is_a?(Hash)
    raise Scim::InvalidRequest.new("A PATCH needs a list of Operations", scim_type: "invalidSyntax") unless operations.is_a?(Array)

    changes = new("username" => user.email, "externalid" => user.external_id,
      "active" => user.active?, "name.formatted" => user.name)
    operations.each { changes.apply(it) }
    changes.attributes
  end

  def initialize(values = {})
    @values = values
  end

  def apply(operation)
    op, path, value = operation.values_at("op", "path", "value") if operation.is_a?(Hash)

    case op.to_s.downcase
    when "add", "replace" then merge_value(path, value)
    when "remove" then path.present? ? merge_value(path, nil) : raise(Scim::InvalidRequest.new("A remove needs a path", scim_type: "noTarget"))
    else raise Scim::InvalidRequest.new("Unknown operation #{op.inspect}", scim_type: "invalidSyntax")
    end
  end

  # Sets the attribute at path; without one, value is a hash of attributes to set
  def merge_value(path, value)
    if path.blank? || (path.to_s.downcase == "name" && value.is_a?(Hash))
      raise Scim::InvalidRequest.new("Expected attributes to set, not #{value.inspect}") unless value.is_a?(Hash)

      value.each { |key, nested| merge_value([ path.presence, key ].compact.join("."), nested) }
    else
      set(path.to_s.downcase, value)
    end
  end

  def attributes
    {}.tap do |attributes|
      attributes[:email] = @values["email"].presence || @values["username"] if (@values.keys & %w[email username]).any?
      attributes[:name] = name if @values.keys.any? { it.start_with?("name.") || it == "displayname" }
      attributes[:external_id] = @values["externalid"].presence if @values.key?("externalid")
      attributes[:active] = @values["active"].to_s.strip.casecmp?("true") if @values.key?("active")
    end
  end

  private
    def set(path, value)
      case path
      when "username", "externalid", "displayname", "name.formatted", "name.givenname", "name.familyname"
        @values[path] = value
      when "active"
        @values[path] = value.nil? || value
      # emails, or one of them by a filter such as emails[type eq "work"].value
      when "emails", /\Aemails(\[.*\])?(\.value)?\z/
        @values["email"] = value.is_a?(Array) ? primary_email(value) : value
      end
    end

    def primary_email(emails)
      emails = emails.select { it.is_a?(Hash) }
      (emails.find { it["primary"].to_s.casecmp?("true") } || emails.first)&.dig("value")
    end

    # Given and family names, which Locke keeps as one, or the formatted or display name
    def name
      [ @values["name.givenname"], @values["name.familyname"] ].compact_blank.join(" ").presence ||
        @values["name.formatted"].presence || @values["displayname"].presence
    end
end
