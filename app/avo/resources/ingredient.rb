class Avo::Resources::Ingredient < Avo::BaseResource
  self.title = :name
  self.icon = "tabler/outline/leaf"

  def fields
    field :id, as: :id
    field :name, as: :text, required: true
    field :optional, as: :boolean
    field :aliases, as: :tags
  end

  def actions
    action Avo::Actions::SyncIngredientsFromAliasCatalog, icon: "tabler/outline/refresh"
    action Avo::Actions::DeleteSelectedIngredients, icon: "tabler/outline/trash"
  end
end
