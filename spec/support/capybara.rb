require "capybara/rspec"

# Allow browser to connect to the test server
WebMock.disable_net_connect!(allow_localhost: true)

# More Puma threads for serving assets in parallel
Capybara.server = :puma, { Threads: "4:4", Silent: true }

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  chrome_binary = ["/usr/bin/chromium-browser", "/usr/bin/google-chrome", "/usr/bin/google-chrome-stable"].find { |p| File.exist?(p) }
  options.binary = chrome_binary if chrome_binary
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,900")

  # Use local chromedriver if available — bypass Selenium Manager network calls
  chromedriver_path = ["/usr/bin/chromedriver", "/usr/local/bin/chromedriver"].find { |p| File.exist?(p) }
  driver_opts = { browser: :chrome, options: options }
  driver_opts[:service] = Selenium::WebDriver::Service.chrome(path: chromedriver_path) if chromedriver_path
  Capybara::Selenium::Driver.new(app, **driver_opts)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :headless_chrome

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.current_driver = :headless_chrome
  end

  config.after(:each, type: :feature) do
    Capybara.use_default_driver
  end

  # Selenium runs in a separate thread — transactional fixtures don't work.
  config.use_transactional_fixtures = true
  config.before(:each, type: :feature) do
    self.use_transactional_tests = false
  end
  config.after(:each, type: :feature) do
    Capybara.reset_sessions!
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} CASCADE")
    end
  end
end
