# The filters SCIM clients send to find a user before creating or changing them,
# such as userName eq "ada@example.com": one attribute, compared for equality.
class Scim::UserFilter
  FORMAT = /\A\s*(?<attribute>[\w.:]+)\s+eq\s+"(?<value>(?:[^"\\]|\\.)*)"\s*\z/i
  COLUMNS = { "username" => :email, "emails" => :email, "emails.value" => :email, "externalid" => :external_id, "id" => :public_id }.freeze

  def initialize(filter)
    @filter = filter
  end

  def apply(users)
    return users if @filter.blank?

    match = FORMAT.match(@filter)
    column = COLUMNS[match[:attribute].downcase] if match
    raise Scim::InvalidRequest.new("Only filters like userName eq \"value\" are supported", scim_type: "invalidFilter") unless column

    users.where(column => match[:value].gsub(/\\(.)/, '\1'))
  end
end
