require "rails_helper"

RSpec.describe "Maintenance tasks", type: :request do
  it "requires basic authentication" do
    get "/maintenance_tasks"

    expect(response).to have_http_status(:unauthorized)
  end
end
