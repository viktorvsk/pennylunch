# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "penny_lunch/quality/env_access_scanner"

RSpec.describe PennyLunch::Quality::EnvAccessScanner do
  it "passes for documented config and shell environment usage" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("config"))
      FileUtils.mkdir_p(root.join("bin"))
      root.join("config/boot.rb").write("ENV.fetch(\"RAILS_ENV\", \"development\")\n")
      root.join("bin/dev").write("export PORT=\"${PORT:-3000}\"\n")
      root.join("env.example").write("PORT=3000\nRAILS_ENV=development\n")

      result = described_class.new(root: root).call

      expect(result).to be_success
    end
  end

  it "reports direct access outside allowed boundaries" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("app/models"))
      root.join("app/models/example.rb").write("ENV.fetch(\"SECRET_TOKEN\")\n")
      root.join("env.example").write("SECRET_TOKEN=\n")

      result = described_class.new(root: root).call

      expect(result.direct_access_findings.map(&:path)).to contain_exactly("app/models/example.rb")
    end
  end

  it "reports direct credentials access outside central configuration" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("app/models"))
      root.join("app/models/example.rb").write("Rails.application.credentials.dig(:recipe, :api_key)\n")

      result = described_class.new(root: root).call

      expect(result.credentials_access_findings.map(&:path)).to contain_exactly("app/models/example.rb")
    end
  end

  it "allows direct source access in central configuration" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("config/initializers"))
      root.join("config/initializers/penny_lunch_configuration.rb").write(<<~RUBY)
        ENV.fetch("RECIPE_API_KEY")
        Rails.application.credentials.dig(:recipe, :api_key)
      RUBY
      root.join("env.example").write("RECIPE_API_KEY=\n")

      result = described_class.new(root: root).call

      expect(result).to be_success
    end
  end

  it "reports undocumented central configuration environment keys" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("config/initializers"))
      root.join("config/initializers/penny_lunch_configuration.rb").write("penny_lunch_config.add_config(:recipe_api_key, nil)\n")
      root.join("env.example").write("")

      result = described_class.new(root: root).call

      expect(result.undocumented_names).to contain_exactly("RECIPE_API_KEY")
    end
  end

  it "ignores scanner implementation patterns" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("lib/penny_lunch/quality"))
      root.join("lib/penny_lunch/quality/env_access_scanner.rb").write("DIRECT_ENV_PATTERN = /ENV/\n")

      result = described_class.new(root: root).call

      expect(result).to be_success
    end
  end

  it "reports undocumented environment names" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("config"))
      root.join("config/puma.rb").write("ENV.fetch(\"PORT\", 3000)\n")
      root.join("env.example").write("")

      result = described_class.new(root: root).call

      expect(result.undocumented_names).to contain_exactly("PORT")
    end
  end

  it "does not require process PATH to be documented as application configuration" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      FileUtils.mkdir_p(root.join("config"))
      root.join("config/boot.rb").write("ENV[\"PATH\"] = \"/app/bin:\#{ENV[\"PATH\"]}\"\n")
      root.join("env.example").write("")

      result = described_class.new(root: root).call

      expect(result).to be_success
    end
  end
end
