# The signed-in user's general settings: name, time zone and theme
class AccountsController < ApplicationController
  PREFERENCES = %w[name time_zone theme].freeze

  layout "account"

  before_action :set_user

  def show
  end

  # One preference at a time, edited in place on the account page
  def edit
    @editing = params[:field].presence_in(PREFERENCES) or return redirect_to(account_path)
    render :show
  end

  def update
    if @user.update(preferences_params)
      redirect_to account_path, notice: "Preferences saved."
    else
      @editing = (preferences_params.keys & PREFERENCES).first
      render :show, status: :unprocessable_content
    end
  end

  private

  # A separate copy, so the layout keeps the saved theme and name when the form is invalid
  def set_user
    @user = User.find(Current.user.id)
  end

  def preferences_params
    params.expect(user: PREFERENCES.map(&:to_sym))
  end
end
