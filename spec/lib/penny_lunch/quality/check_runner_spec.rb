# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "stringio"
require "tmpdir"
require "penny_lunch/quality/check_runner"

RSpec.describe PennyLunch::Quality::CheckRunner do
  it "returns success when all tasks succeed" do
    Dir.mktmpdir do |directory|
      output = StringIO.new
      tasks = [
        described_class::Task.new(name: "one", command: [ RbConfig.ruby, "-e", "puts 'ok'" ])
      ]

      status = described_class.new(tasks: tasks, root: Pathname.new(directory), output: output).run

      expect(status).to eq(0)
      expect(output.string).to include("SUCCESS: one")
    end
  end

  it "returns failure when a task fails" do
    Dir.mktmpdir do |directory|
      output = StringIO.new
      tasks = [
        described_class::Task.new(name: "bad", command: [ RbConfig.ruby, "-e", "warn 'no'; exit 2" ])
      ]

      status = described_class.new(tasks: tasks, root: Pathname.new(directory), output: output).run

      expect(status).to eq(1)
      expect(output.string).to include("FAILED: bad")
      expect(output.string).to include("no")
    end
  end

  it "runs exclusive tasks after parallel tasks" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      output = StringIO.new
      marker = root.join("parallel-done").to_s
      tasks = [
        described_class::Task.new(name: "parallel", command: [ RbConfig.ruby, "-e", "sleep 0.1; File.write(#{marker.inspect}, 'done')" ]),
        described_class::Task.new(name: "exclusive", command: [ RbConfig.ruby, "-e", "exit(File.exist?(#{marker.inspect}) ? 0 : 1)" ], exclusive: true)
      ]

      status = described_class.new(tasks: tasks, root:, output:).run

      expect(status).to eq(0)
      expect(output.string).to include("SUCCESS: parallel")
      expect(output.string).to include("SUCCESS: exclusive")
    end
  end
end
