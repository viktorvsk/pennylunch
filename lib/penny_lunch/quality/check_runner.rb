# frozen_string_literal: true

require "open3"
require "pathname"

module PennyLunch
  module Quality
    class CheckRunner
      Task = Struct.new(:name, :command, :exclusive, keyword_init: true)
      Result = Struct.new(:task, :output, :status, :elapsed, keyword_init: true) do
        def success?
          status.success?
        end
      end

      TASKS = [
        Task.new(name: "rubocop", command: [ "bin/rubocop" ]),
        Task.new(name: "flay", command: [ "bin/linters/flay" ]),
        Task.new(name: "flog", command: [ "bin/linters/flog" ]),
        Task.new(name: "reek", command: [ "bin/linters/reek" ]),
        Task.new(name: "brakeman", command: [ "bin/linters/brakeman" ]),
        Task.new(name: "bundler-audit", command: [ "bin/linters/bundler-audit" ]),
        Task.new(name: "env_access", command: [ "bin/linters/env_access" ]),
        Task.new(name: "production_boot", command: [ "bin/linters/production_boot" ]),
        Task.new(name: "coverage", command: [ "bin/linters/coverage" ], exclusive: true),
        Task.new(name: "rspec", command: [ "bin/rspec" ], exclusive: true)
      ].freeze

      def initialize(tasks: TASKS, root: Pathname.new(__dir__).join("../../..").expand_path, output: $stdout)
        @tasks = tasks
        @root = root
        @output = output
      end

      def run
        results = []
        mutex = Mutex.new
        parallel_tasks, exclusive_tasks = tasks.partition { |task| !task.exclusive }
        threads = parallel_tasks.map do |task|
          Thread.new do
            result = run_task(task)
            mutex.synchronize { results << result }
          end
        end

        threads.each(&:join)
        exclusive_tasks.each { |task| results << run_task(task) }
        results.sort_by { |result| tasks.index(result.task) }.each { |result| print_result(result) }
        results.all?(&:success?) ? 0 : 1
      end

      private

      attr_reader :tasks, :root, :output

      def run_task(task)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stdout, stderr, status = Open3.capture3(environment, *task.command, chdir: root.to_s)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
        Result.new(task: task, output: [ stdout, stderr ].join, status: status, elapsed: elapsed)
      end

      def environment
        { "DISABLE_SPRING" => "1", "SILENT_TESTS" => "1" }
      end

      def print_result(result)
        if result.success?
          output.puts "SUCCESS: #{result.task.name} (#{format_elapsed(result.elapsed)})"
        else
          output.puts "FAILED: #{result.task.name} (#{format_elapsed(result.elapsed)})"
          output.puts result.output
        end
      end

      def format_elapsed(elapsed)
        format("%.2fs", elapsed)
      end
    end
  end
end
