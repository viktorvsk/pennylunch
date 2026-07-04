Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless, screen_size: [ 1280, 900 ]
  end
end
