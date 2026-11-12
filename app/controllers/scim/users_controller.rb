# The tenant's users, as SCIM Users. Every user can be read, so a provider can
# find the accounts its people already have; writing to one makes the provider
# manage it (see UserProvisioning).
class Scim::UsersController < ScimController
  MAX_RESULTS = 200

  before_action :set_user, only: %i[show update destroy]

  def index
    users = Scim::UserFilter.new(params[:filter]).apply(User.order(:id))
    start_index = [ params[:startIndex].to_i, 1 ].max
    page = users.offset(start_index - 1).limit(params.fetch(:count, MAX_RESULTS).to_i.clamp(0, MAX_RESULTS)).to_a

    render_scim({ schemas: [ Scim::LIST_SCHEMA ], totalResults: users.count, startIndex: start_index,
      itemsPerPage: page.size, Resources: page.map { resource(it) } })
  end

  def show
    render_scim resource(@user)
  end

  def create
    respond_with provisioning.create(Scim::UserChanges.from_resource(scim_body)), status: :created
  end

  # PUT replaces the user's attributes; PATCH changes some of them
  def update
    changes = request.patch? ? Scim::UserChanges.from_patch(scim_body, @user) : Scim::UserChanges.from_resource(scim_body)
    respond_with provisioning.update(@user, changes)
  end

  # Accounts are deactivated rather than deleted: they keep their history, and apps may still know them
  def destroy
    user = provisioning.update(@user, active: false)
    user.errors.any? ? respond_with(user) : head(:no_content)
  end

  private
    def set_user
      @user = User.find_by!(public_id: params[:id])
    end

    def provisioning = UserProvisioning.new(identity_provider)

    def resource(user) = Scim::UserResource.new(user, location: scim_user_url(user.public_id))

    def respond_with(user, status: :ok)
      if user.errors.none?
        render_scim resource(user), status:, location: scim_user_url(user.public_id)
      elsif user.errors.of_kind?(:base, :managed_elsewhere)
        render_error user.errors.full_messages.to_sentence, status: :forbidden
      elsif user.errors.of_kind?(:email, :taken)
        render_error user.errors.full_messages.to_sentence, status: :conflict, scim_type: "uniqueness"
      else
        render_error user.errors.full_messages.to_sentence, status: :bad_request, scim_type: "invalidValue"
      end
    end
end
