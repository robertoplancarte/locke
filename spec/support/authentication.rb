module AuthenticationHelpers
  module Request
    def sign_in_as(user, password: "correct horse battery")
      post sign_in_path, params: { email: user.email, password: }
    end
  end

  module System
    def sign_in_as(user, password: "correct horse battery")
      visit "/sign_in"
      fill_in "Email address", with: user.email
      fill_in "Password", with: password
      click_on "Sign in"
      # Wait for the session cookie before the spec navigates elsewhere
      expect(page).to have_text("Signed in successfully")
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers::Request, type: :request
  config.include AuthenticationHelpers::System, type: :system
end

# User validates passwords against the Pwned Passwords API; report every password as unseen.
# A global stub survives WebMock's per-example reset, so let_it_be setup is covered too.
WebMock.globally_stub_request do |request|
  { body: "" } if request.uri.host == "api.pwnedpasswords.com"
end
