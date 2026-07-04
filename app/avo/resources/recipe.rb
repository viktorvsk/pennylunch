class Avo::Resources::Recipe < Avo::BaseResource
  self.title = :title
  self.icon = "tabler/outline/tools-kitchen-2"
  self.find_record_method = -> {
    recipe_ids = Array(id).map { |value| model_class.id_from_param(value) }

    id.is_a?(Array) ? query.find(recipe_ids) : query.find(recipe_ids.first)
  }

  def fields
    field :id, as: :id
    field :title, as: :text
    field :category, as: :text
    field :author, as: :text
    field :ratings, as: :number
    field :total_time, as: :number
    field :ingredient_names, as: :tags
  end

  def actions
    action Avo::Actions::ImportRecipes, icon: "tabler/outline/download"
    action Avo::Actions::IndexSelectedRecipes, icon: "tabler/outline/database"
    action Avo::Actions::SetRecipeSearchStrategy, icon: "tabler/outline/adjustments"
    action Avo::Actions::DeleteSelectedRecipes, icon: "tabler/outline/trash"
  end

  def render_index_controls(**)
    [
      Avo::Resources::Controls::BackButton.new,
      Avo::Resources::Controls::ActionsList.new(as_index_control: true)
    ]
  end

  def render_show_controls
    [
      Avo::Resources::Controls::BackButton.new,
      Avo::Resources::Controls::ActionsList.new
    ]
  end

  def render_edit_controls
    [
      Avo::Resources::Controls::BackButton.new(label: I18n.t("avo.cancel").capitalize)
    ]
  end

  def render_row_controls(item:)
    [
      Avo::Resources::Controls::ShowButton.new(item:)
    ]
  end
end
