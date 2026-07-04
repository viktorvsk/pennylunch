FactoryBot.define do
  factory :recipe do
    sequence(:title) { |index| "Weeknight Lemon Chicken #{index}" }
    cook_time { 20 }
    prep_time { 10 }
    ingredients { [ "1 lemon", "2 chicken breasts", "1 teaspoon salt" ] }
    ingredient_names { ingredients.map { |ingredient| ingredient.to_s.gsub(/\A[\d\s\/.]+/, "").squish.downcase }.uniq }
    ingredient_parse_data do
      ingredients.map do |ingredient|
        {
          "input" => ingredient,
          "parser" => {
            "sentence" => ingredient
          }
        }
      end
    end
    ratings { 4.7 }
    cuisine { "" }
    category { "Dinner" }
    category_normalized { category.downcase }
    author { "Penny Cook" }
    image { "https://example.com/recipe.jpg" }
    total_time { prep_time + cook_time }
    sequence(:source_position)
    source_key { Recipe.source_key_for(title:, category:, author:) }
  end
end
