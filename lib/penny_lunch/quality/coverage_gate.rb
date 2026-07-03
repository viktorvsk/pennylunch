# frozen_string_literal: true

require "json"
require "pathname"

module PennyLunch
  module Quality
    class CoverageGate
      Result = Struct.new(:success, :message, :percent, keyword_init: true) do
        def success?
          success
        end
      end

      def initialize(path: Pathname.new("coverage/coverage.json"), threshold: 90.0)
        @path = path
        @threshold = threshold
      end

      def call
        return failure("Coverage check failed: no coverage/coverage.json found.") unless path.exist?

        data = JSON.parse(path.read)
        percent = overall_percent(data)
        return failure("Coverage check failed: could not determine overall line coverage.") if percent.nil?
        return failure("Coverage check failed: #{format_percent(percent)}% is below #{format_percent(threshold)}%.", percent) if percent < threshold

        Result.new(success: true, message: "Coverage check passed: #{format_percent(percent)}% overall line coverage.", percent: percent)
      rescue JSON::ParserError
        failure("Coverage check failed: coverage/coverage.json is not valid JSON.")
      end

      private

      attr_reader :path, :threshold

      def overall_percent(data)
        coverage = data["coverage"]
        return unless coverage.is_a?(Hash)

        covered = 0
        total = 0

        coverage.each_value do |file_data|
          lines = file_data["lines"]
          next unless lines.is_a?(Array)

          lines.compact.each do |visits|
            total += 1
            covered += 1 if visits.to_i.positive?
          end
        end

        return if total.zero?

        (covered.to_f / total) * 100
      end

      def failure(message, percent = nil)
        Result.new(success: false, message: message, percent: percent)
      end

      def format_percent(percent)
        percent == percent.to_i ? percent.to_i.to_s : format("%.2f", percent)
      end
    end
  end
end
