require "capybara/rspec"

# Allow Selenium to connect to the test server
WebMock.disable_net_connect!(allow_localhost: true)

Capybara.register_driver :headless_selenium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = "/usr/bin/chromium-browser"
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,900")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :headless_selenium

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.current_driver = :headless_selenium
  end

  config.after(:each, type: :feature) do
    Capybara.use_default_driver
  end

  # Selenium runs in a separate thread — transactional fixtures don't work.
  # Use truncation for feature specs instead.
  config.use_transactional_fixtures = true
  config.before(:each, type: :feature) do
    self.use_transactional_tests = false
  end
  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
    # Clean up database after each feature spec
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} CASCADE")
    end
  end
end
