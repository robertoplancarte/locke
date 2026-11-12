# How many of the current tenant's users there are, for the user management dashboard
class UserCounts
  RECENT = 30.days

  def active = User.active.count

  def deactivated = User.deactivated.count

  # Active users who signed in during the last RECENT, from their security log
  def signed_in_recently
    User.active.where(id: Event.where(action: %w[signed_in signed_in_again], created_at: RECENT.ago..).select(:user_id)).count
  end

  # Active users each identity provider manages, for the providers that manage any
  def managed_by_provider
    counts = User.active.where.not(managed_by_id: nil).group(:managed_by_id).count
    IdentityProvider.where(id: counts.keys).order(:name).to_h { [ it, counts[it.id] ] }
  end
end
