require "webmock/rspec"

# Specs must never reach real external APIs; the Capybara server runs on localhost.
WebMock.disable_net_connect!(allow_localhost: true)
