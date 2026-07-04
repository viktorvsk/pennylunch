class RemoveSlugFromRecipes < ActiveRecord::Migration[8.1]
  class MigrationRecipe < ActiveRecord::Base
    self.table_name = "recipes"
  end

  def up
    remove_index :recipes, :slug
    remove_column :recipes, :slug
  end

  def down
    add_column :recipes, :slug, :string

    MigrationRecipe.reset_column_information
    seen_slugs = {}
    MigrationRecipe.find_each do |recipe|
      base_slug = [
        recipe.title,
        recipe.category,
        recipe.author,
        "#{recipe.total_time}-minutes"
      ].filter_map { |part| part.to_s.parameterize(preserve_case: true).presence }.join("-")
      slug = base_slug.presence || recipe.id.to_s
      duplicate_count = 2

      while seen_slugs.key?(slug)
        slug = "#{base_slug}-#{duplicate_count}"
        duplicate_count += 1
      end

      seen_slugs[slug] = true
      recipe.update_columns(slug:)
    end

    change_column_null :recipes, :slug, false
    add_index :recipes, :slug, unique: true
  end
end
