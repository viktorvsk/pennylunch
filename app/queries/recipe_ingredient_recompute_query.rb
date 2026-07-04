# Builds SQL that synchronizes `recipe_ingredients` rows for the given recipes
# from each recipe's normalized `ingredient_names` JSON array.
#
# Returns a SQL string intended for `Recipe.connection.exec_query`. The
# statement deletes stale recipe/ingredient pairs and inserts missing pairs by
# matching each parsed name against `ingredients.name` and `ingredients.aliases`.
#
# Example generated query:
#   WITH target_recipes AS (SELECT "recipes"."id" FROM "recipes" WHERE "recipes"."id" IN (1, 2)),
#   desired_pairs AS (... jsonb_array_elements_text(recipes.ingredient_names) ...),
#   deleted_pairs AS (DELETE FROM recipe_ingredients ...)
#   INSERT INTO recipe_ingredients (...) SELECT ... ON CONFLICT (recipe_id, ingredient_id) DO NOTHING
class RecipeIngredientRecomputeQuery
  class << self
    def call(recipe_ids:)
      <<~SQL.squish
        WITH target_recipes AS (
          #{Recipe.where(id: recipe_ids).select(:id).to_sql}
        ),
        desired_pairs AS (
          SELECT DISTINCT recipes.id AS recipe_id, ingredients.id AS ingredient_id
          FROM target_recipes
          INNER JOIN recipes ON recipes.id = target_recipes.id
          CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(recipes.ingredient_names, '[]'::jsonb)) AS parsed(raw_name)
          INNER JOIN ingredients
            ON ingredients.name = parsed.raw_name
            OR ingredients.aliases ? parsed.raw_name
        ),
        deleted_pairs AS (
          DELETE FROM recipe_ingredients
          USING target_recipes
          WHERE recipe_ingredients.recipe_id = target_recipes.id
            AND NOT EXISTS (
              SELECT 1
              FROM desired_pairs
              WHERE desired_pairs.recipe_id = recipe_ingredients.recipe_id
                AND desired_pairs.ingredient_id = recipe_ingredients.ingredient_id
            )
        )
        INSERT INTO recipe_ingredients (
          recipe_id,
          ingredient_id,
          created_at,
          updated_at
        )
        SELECT desired_pairs.recipe_id, desired_pairs.ingredient_id, NOW(), NOW()
        FROM desired_pairs
        ON CONFLICT (recipe_id, ingredient_id) DO NOTHING
      SQL
    end
  end
end
