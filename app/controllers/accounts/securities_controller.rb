module Accounts
  # How the user signs in: password, email, providers and two-factor authentication
  class SecuritiesController < ApplicationController
    layout "account"

    def show
      @user = Current.user
    end
  end
end
