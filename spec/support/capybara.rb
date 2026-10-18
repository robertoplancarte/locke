require "capybara/rspec"

# Headless by default; HEADFUL=1 opens a visible browser for local debugging.
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(
    app,
    browser_type: :chromium,
    headless: ENV["HEADFUL"].blank?,
    playwright_cli_executable_path: Rails.root.join("node_modules/.bin/playwright").to_s
  )
end

Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :playwright
  end

  # Record a Playwright trace for every system spec and keep it only when the
  # spec fails. Open with `npx playwright show-trace tmp/traces/<name>.zip`.
  config.before(:each, type: :system) do
    page.driver.start_tracing(screenshots: true, snapshots: true, sources: true)
  end

  config.after(:each, type: :system) do |example|
    path = Rails.root.join("tmp/traces/#{example.full_description.parameterize}.zip").to_s if example.exception
    page.driver.stop_tracing(path: path)
  end
end
