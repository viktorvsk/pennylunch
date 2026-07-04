module Maintenance
  class RestoreRecipeRawIngredientNamesTask < MaintenanceTasks::Task
    BATCH_SIZE = 128

    def collection
      Recipe.in_batches(of: BATCH_SIZE)
    end

    def process(records)
      recipes = records.is_a?(Recipe) ? [ records ] : records.to_a

      recipes.each do |recipe|
        names = raw_names_from(recipe.ingredient_parse_data)
        next if names.empty? || names == recipe.ingredient_names

        recipe.update!(ingredient_names: names)
      end
    end

    private

    def raw_names_from(parse_data)
      Array(parse_data).flat_map do |entry|
        parser_name = entry.dig("parser", "name") if entry.is_a?(Hash)
        Array(parser_name).filter_map { |name| name.is_a?(Hash) ? name["text"] : name }
      end.filter_map { |name| name.to_s.squish.downcase.presence }.uniq
    end
  end
end
