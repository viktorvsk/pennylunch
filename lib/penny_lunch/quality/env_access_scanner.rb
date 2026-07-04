# frozen_string_literal: true

require "pathname"

module PennyLunch
  module Quality
    class EnvAccessScanner
      Finding = Struct.new(:path, :line_number, :line, keyword_init: true) do
        def to_s
          "#{path}:#{line_number}: #{line.strip}"
        end
      end

      Result = Struct.new(:direct_access_findings, :credentials_access_findings, :undocumented_names, keyword_init: true) do
        def success?
          direct_access_findings.empty? && credentials_access_findings.empty? && undocumented_names.empty?
        end
      end

      RULES = {
        scan_globs: [
          "app/**/*.{rb,rake,yml,yaml,erb}",
          "bin/**/*",
          "config/**/*.{rb,rake,yml,yaml,erb}",
          "db/**/*.rb",
          "lib/**/*.{rb,rake,erb}"
        ].freeze,
        skipped_path_parts: [
          "/coverage/",
          "/log/",
          "/spec/",
          "/storage/",
          "/test/",
          "/tmp/",
          "/vendor/"
        ].freeze,
        skipped_paths: [
          "lib/penny_lunch/quality/env_access_scanner.rb"
        ].freeze,
        central_configuration_paths: [
          "config/initializers/penny_lunch_configuration.rb"
        ].freeze,
        built_in_env_names: [
          "PATH"
        ].freeze
      }.freeze

      PATTERNS = {
        direct_env: /\bENV\b(?:\s*\[|\.fetch|\.key\?|\.delete|\.)?/,
        direct_credentials: /\bRails\.application\.credentials\b/,
        ruby_env_name: /ENV(?:\s*\[\s*|\.fetch\(\s*|\.key\?\(\s*|\.delete\(\s*)["']([A-Z][A-Z0-9_]*)["']/,
        config_env_name: /add_config\(\s*:([a-z][a-z0-9_]*)/,
        shell_env_name: /\$\{([A-Z][A-Z0-9_]*)/
      }.freeze

      class << self
        def call(root: Pathname.new(__dir__).join("../../..").expand_path, env_file: "env.example")
          new(root:, env_file:).scan
        end
      end

      def initialize(root:, env_file:)
        @root = root
        @env_file = env_file
        @findings = { direct: [], credentials: [], referenced: [] }
      end

      def scan
        files.each do |absolute_path|
          path = relative_path(absolute_path)
          next if skipped?(path)

          scan_file(absolute_path, path)
        end

        Result.new(
          direct_access_findings: @findings[:direct],
          credentials_access_findings: @findings[:credentials],
          undocumented_names: @findings[:referenced].uniq.sort - documented_names
        )
      end

      private

      def scan_file(absolute_path, path)
        File.readlines(absolute_path, encoding: "UTF-8").each_with_index do |line, index|
          next if line.lstrip.start_with?("#")

          @findings[:referenced].concat(environment_names(line))
          @findings[:referenced].concat(shell_environment_names(line)) if path.start_with?("bin/")

          if line.match?(PATTERNS[:direct_env]) && !env_allowed?(path)
            @findings[:direct] << Finding.new(path: path, line_number: index + 1, line: line)
          end

          if line.match?(PATTERNS[:direct_credentials]) && !central_configuration?(path)
            @findings[:credentials] << Finding.new(path: path, line_number: index + 1, line: line)
          end
        end
      end

      def files
        RULES[:scan_globs].flat_map { |glob| Dir.glob(@root.join(glob)) }.uniq.select { |path| File.file?(path) }.sort
      end

      def relative_path(absolute_path)
        Pathname.new(absolute_path).relative_path_from(@root).to_s
      end

      def skipped?(path)
        RULES[:skipped_paths].include?(path) || RULES[:skipped_path_parts].any? { |part| "/#{path}".include?(part) }
      end

      def environment_names(line)
        line.scan(PATTERNS[:ruby_env_name]).flatten + line.scan(PATTERNS[:config_env_name]).flatten.map(&:upcase)
      end

      def shell_environment_names(line)
        line.scan(PATTERNS[:shell_env_name]).flatten
      end

      def env_allowed?(path)
        path.start_with?("bin/") || path.start_with?("config/") || central_configuration?(path)
      end

      def central_configuration?(path)
        RULES[:central_configuration_paths].include?(path)
      end

      def documented_names
        path = @root.join(@env_file)
        return RULES[:built_in_env_names] unless path.exist?

        names = path.readlines.filter_map do |line|
          next if line.lstrip.start_with?("#")

          line[/\A(?:export\s+)?([A-Z][A-Z0-9_]*)=/, 1]
        end

        (RULES[:built_in_env_names] + names).sort
      end
    end
  end
end
