# A user as a SCIM User resource. The id is the user's public id, the sub claim apps see.
class Scim::UserResource
  def initialize(user, location:)
    @user, @location = user, location
  end

  def as_json(*)
    {
      schemas: [ Scim::USER_SCHEMA ],
      id: @user.public_id,
      externalId: @user.external_id,
      userName: @user.email,
      name: ({ formatted: @user.name } if @user.name),
      displayName: @user.display_name,
      emails: [ { value: @user.email, type: "work", primary: true } ],
      active: @user.active?,
      meta: { resourceType: "User", created: @user.created_at.iso8601, lastModified: @user.updated_at.iso8601, location: @location }
    }.compact
  end
end
