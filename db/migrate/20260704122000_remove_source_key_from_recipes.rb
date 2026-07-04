require "digest"

class RemoveSourceKeyFromRecipes < ActiveRecord::Migration[8.1]
  class MigrationRecipe < ActiveRecord::Base
    self.table_name = "recipes"
  end

  def up
    remove_index :recipes, :source_key
    remove_column :recipes, :source_key
  end

  def down
    add_column :recipes, :source_key, :string

    MigrationRecipe.reset_column_information
    MigrationRecipe.find_each do |recipe|
      recipe.update_columns(source_key: Digest::SHA256.hexdigest(JSON.generate([
        recipe.title.to_s.strip.downcase,
        recipe.category.to_s.strip.downcase,
        recipe.author.to_s.strip.downcase
      ])))
    end

    change_column_null :recipes, :source_key, false
    add_index :recipes, :source_key, unique: true
  end
end
