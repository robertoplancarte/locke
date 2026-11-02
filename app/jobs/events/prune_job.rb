module Events
  # Deletes security events past their retention period, so personal data
  # like IP addresses isn't kept longer than it's useful
  class PruneJob < ApplicationJob
    def perform
      Event.expired.in_batches.delete_all
    end
  end
end
