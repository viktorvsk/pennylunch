# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "penny_lunch/quality/coverage_gate"

RSpec.describe PennyLunch::Quality::CoverageGate do
  it "passes when overall coverage meets the threshold" do
    Dir.mktmpdir do |directory|
      path = Pathname.new(directory).join("coverage.json")
      path.write({ coverage: { "app/example.rb" => { lines: [ 1, 1, 0, nil ] } } }.to_json)

      result = described_class.call(path: path, threshold: 60.0)

      expect(result).to be_success
      expect(result.percent).to be_within(0.01).of(100.0 * 2 / 3)
    end
  end

  it "fails when coverage is below the threshold" do
    Dir.mktmpdir do |directory|
      path = Pathname.new(directory).join("coverage.json")
      path.write({ coverage: { "app/example.rb" => { lines: [ 1, 0, 0 ] } } }.to_json)

      result = described_class.call(path: path, threshold: 90.0)

      expect(result).not_to be_success
      expect(result.message).to include("below 90")
    end
  end

  it "fails when the coverage artifact is missing" do
    result = described_class.call(path: Pathname.new("/tmp/pennylane-missing-coverage.json"))

    expect(result).not_to be_success
    expect(result.message).to include("no coverage/coverage.json")
  end
end
