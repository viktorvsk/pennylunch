require "rails_helper"

RSpec.describe "App Ruby style" do
  it "keeps app service and query call APIs class-level" do
    paths = Dir.glob(Rails.root.join("app/{services,queries}/**/*.rb")).map { |path| Pathname.new(path) }
    offenders = paths.select do |path|
      source = path.read
      source.match?(/^  def call\b/) || source.match?(/^\s*def self\.call\b/)
    end

    expect(offenders.map { |path| path.relative_path_from(Rails.root).to_s }).to be_empty
  end

  it "keeps query objects passive" do
    paths = Dir.glob(Rails.root.join("app/queries/**/*.rb")).map { |path| Pathname.new(path) }
    offenders = paths.select do |path|
      path.read.match?(/\.(execute|exec_query|update_all|delete_all|insert_all|upsert_all)\b/)
    end

    expect(offenders.map { |path| path.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
