class Avo::Actions::ImportRecipes < Avo::BaseAction
  self.name = "Import recipes"
  self.message = "Import recipes from the source URL?"
  self.confirm_button_label = "Queue import"
  self.standalone = true

  def fields
    field :url, as: :text, default: RecipeImport::DEFAULT_URL, required: true
  end

  def handle(fields:, **)
    url = fields[:url].to_s.squish
    return error("Recipe import URL can't be blank.").keep_modal_open if url.blank?
    return error("Recipes must be deleted before importing.").keep_modal_open if Recipe.exists?

    ImportRecipesJob.perform_later(url)
    succeed "Queued recipe import."
    reload
  end
end
