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

# Keep the test server's port when a spec points app_host at a tenant subdomain
Capybara.always_include_port = true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :playwright
  end

  # Record a Playwright trace for every system spec and keep it only when the
  # spec fails, or always with TRACES=1. Open with
  # `npx playwright show-trace tmp/traces/<name>.zip`.
  config.before(:each, type: :system) do
    page.driver.start_tracing(screenshots: true, snapshots: true, sources: true)
  end

  config.after(:each, type: :system) do |example|
    name = example.full_description.parameterize

    # SCREENSHOTS=1 saves a full-page screenshot of where every spec ended up
    # (failures are always captured in tmp/capybara by Rails).
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s, full: true) if ENV["SCREENSHOTS"].present?

    path = Rails.root.join("tmp/traces/#{name}.zip").to_s if example.exception || ENV["TRACES"].present?
    page.driver.stop_tracing(path: path)
  end
end
