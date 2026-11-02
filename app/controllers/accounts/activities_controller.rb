module Accounts
  # Where the user is signed in, and what's happened on their account lately
  class ActivitiesController < ApplicationController
    RECENT_EVENTS = 10

    layout "account"

    def show
      @sessions = Current.user.sessions.order(created_at: :desc)
      @events = Current.user.events.order(created_at: :desc).limit(RECENT_EVENTS)
    end
  end
end
