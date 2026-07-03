penny_lunch_config = Rails.application.config.penny_lunch = ActiveSupport::OrderedOptions.new

def penny_lunch_config.add_config(name, value)
  environment_name = name.to_s.upcase
  self[name] = ENV.key?(environment_name) ? ENV[environment_name].presence : value
end

penny_lunch_config.add_config(:recipes_import_url, "https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz")
penny_lunch_config.add_config(:ingredients_filter_strategy, "naive_vector_search")
penny_lunch_config.add_config(:ingredients_candidate_count, "250")
penny_lunch_config.add_config(:ingredients_max_cosine_distance, "0.7")
penny_lunch_config.add_config(:ingredient_parser_python, Rails.root.join(".venv", "bin", "python").to_s)
penny_lunch_config.add_config(:ingredient_parser_script, Rails.root.join("libexec", "parse_ingredients.py").to_s)
penny_lunch_config.add_config(:ingredient_parser_timeout_seconds, "120")
penny_lunch_config.add_config(:informers_cache_dir, Rails.root.join("storage", "informers").to_s)
penny_lunch_config.add_config(:embedding_model_preload, "true")
penny_lunch_config.add_config(:maintenance_tasks_username, "pennylunch")
penny_lunch_config.add_config(:maintenance_tasks_password, "pennylunch")
