# frozen_string_literal: true

if ENV["COVERAGE"] == "1"
  require "simplecov"

  if ENV["COVERAGE_FORMAT"] == "json"
    require "simplecov_json_formatter"
    SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  end

  SimpleCov.start("rails") do
    add_filter "/bin/"
    add_filter "/config/"
    add_filter "/db/"
    add_filter "/spec/"
    track_files "app/**/*.rb"
    track_files "lib/**/*.rb"
  end

  SimpleCov.at_exit do
    Rails.application.eager_load! if defined?(Rails) && Rails.application
    SimpleCov.result.format!
  end
end

RSpec.configure do |config|
  config.order = :random
  Kernel.srand(config.seed)

  config.expect_with(:rspec) do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with(:rspec) do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  if ENV["SILENT_TESTS"] == "1"
    config.deprecation_stream = File.open(File::NULL, "w")
  end
end
