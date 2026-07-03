class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :title, null: false
      t.integer :cook_time, null: false
      t.integer :prep_time, null: false
      t.jsonb :ingredients, null: false, default: []
      t.decimal :ratings, precision: 4, scale: 2, null: false
      t.string :cuisine, null: false, default: ""
      t.string :category, null: false, default: ""
      t.string :category_normalized, null: false, default: ""
      t.string :author, null: false, default: ""
      t.text :image, null: false
      t.integer :total_time, null: false
      t.virtual :title_search_vector, type: :tsvector, as: "to_tsvector('english', coalesce(title, ''))", stored: true
      t.string :source_key, null: false
      t.integer :source_position, null: false
      t.string :slug, null: false
      t.vector :ingredients_vector, limit: 384
      t.timestamps
    end

    add_index :recipes, :category_normalized
    add_index :recipes, :ratings
    add_index :recipes, :slug, unique: true
    add_index :recipes, :source_key, unique: true
    add_index :recipes, :source_position, unique: true
    add_index :recipes, :title_search_vector, using: :gin
    add_index :recipes, :total_time
    add_index :recipes, :ingredients_vector, using: :hnsw, opclass: :vector_cosine_ops, where: "ingredients_vector IS NOT NULL"
  end
end
