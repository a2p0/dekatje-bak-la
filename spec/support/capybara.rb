require "capybara/rspec"
require "capybara/cuprite"

# Allow browser to connect to the test server
WebMock.disable_net_connect!(allow_localhost: true)

Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app,
    headless: true,
    window_size: [ 1400, 900 ],
    browser_options: { "no-sandbox" => nil },
    process_timeout: 30,
    timeout: 10
  )
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  config.before(:each, type: :feature) do
    Capybara.current_driver = :cuprite
  end

  config.after(:each, type: :feature) do
    Capybara.use_default_driver
  end

  # Cuprite runs in a separate thread — transactional fixtures don't work.
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
