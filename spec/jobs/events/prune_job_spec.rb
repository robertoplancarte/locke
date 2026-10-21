require "rails_helper"

RSpec.describe Events::PruneJob, type: :job do
  subject(:perform) { described_class.new.perform }

  let_it_be(:user) { create(:user) }
  let_it_be(:recent) { user.events.create!(action: "signed_in", created_at: 89.days.ago) }

  before_all { user.events.create!(action: "signed_in", created_at: 91.days.ago) }

  it "deletes only events past the retention period" do
    perform

    expect(Event.all).to contain_exactly(recent)
  end
end
