require "rails_helper"

RSpec.describe "JavaScript architecture" do
  it "loads custom application behavior through importmap and Stimulus" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read
    asset_scripts = Dir.glob(Rails.root.join("app/assets/javascripts/*.js")).map { |path| Pathname.new(path).relative_path_from(Rails.root).to_s }
    controllers = Dir.glob(Rails.root.join("app/javascript/controllers/**/*_controller.js")).map { |path| File.basename(path) }

    aggregate_failures do
      expect(layout).to include("javascript_importmap_tags")
      expect(layout).not_to include("recipe_filters")
      expect(asset_scripts).to be_empty
      expect(controllers).to include(
        "auto_submit_controller.js",
        "ingredients_fab_controller.js",
        "infinite_scroll_controller.js",
        "ingredient_matches_controller.js",
        "recipe_ui_controller.js"
      )
    end
  end
end
