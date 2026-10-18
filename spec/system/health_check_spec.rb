require "rails_helper"

RSpec.describe "Health check", type: :system do
  it "renders a green page when the app boots" do
    visit rails_health_check_path

    expect(page).to have_css("body[style*='green']")
  end
end
