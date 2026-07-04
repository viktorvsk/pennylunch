require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

RSpec.describe "application configuration" do
  it "exposes PennyLunch config through Rails config" do
    config = Rails.application.config.penny_lunch

    expect(config).to be_a(ActiveSupport::OrderedOptions)
    expect(SETTINGS).to equal(config)
  end

  it "uses environment values before defaults and allows blanks to unset defaults" do
    config = Rails.application.config.penny_lunch
    had_config = config.key?(:temporary_test_value)
    original_config = config[:temporary_test_value]
    had_environment = ENV.key?("TEMPORARY_TEST_VALUE")
    original_environment = ENV["TEMPORARY_TEST_VALUE"]

    ENV["TEMPORARY_TEST_VALUE"] = "from-env"
    config.add_config(:temporary_test_value, "default")

    expect(config.temporary_test_value).to eq("from-env")

    ENV["TEMPORARY_TEST_VALUE"] = ""
    config.add_config(:temporary_test_value, "default")

    expect(config.temporary_test_value).to be_nil
  ensure
    if had_config
      config[:temporary_test_value] = original_config
    else
      config.delete(:temporary_test_value)
    end

    if had_environment
      ENV["TEMPORARY_TEST_VALUE"] = original_environment
    else
      ENV.delete("TEMPORARY_TEST_VALUE")
    end
  end
end
