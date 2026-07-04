class RecipeIndexPage < Data.define(:filters, :recipes, :selected_category, :next_page_url)
  def results_frame_locals
    {
      recipes:,
      selected_category:,
      filters:,
      next_page_url:
    }
  end
end
