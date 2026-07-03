# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application boot" do
  it "loads the application base classes" do
    expect(ApplicationController).to be < ActionController::Base
    expect(ApplicationRecord.abstract_class?).to be(true)
    expect(ApplicationJob).to be < ActiveJob::Base
    expect(ApplicationHelper).to be_a(Module)
  end
end
