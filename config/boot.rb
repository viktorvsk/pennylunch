ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
ENV["PATH"] = [ File.expand_path("../.venv/bin", __dir__), ENV["PATH"] ].compact.join(File::PATH_SEPARATOR)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
