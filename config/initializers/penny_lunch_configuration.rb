penny_lunch_config = Rails.application.config.penny_lunch = ActiveSupport::OrderedOptions.new
SETTINGS = penny_lunch_config

def penny_lunch_config.add_config(name, value)
  environment_name = name.to_s.upcase
  self[name] = ENV.key?(environment_name) ? ENV[environment_name].presence : value
end

penny_lunch_config.add_config(:ingredients_max_cosine_distance, "0.7")
penny_lunch_config.add_config(:ingredient_parser_timeout_seconds, "120")
penny_lunch_config.add_config(:informers_cache_dir, Rails.root.join("storage", "informers").to_s)
penny_lunch_config.add_config(:embedding_model_preload, "true")
penny_lunch_config.add_config(:avo_username, "pennylunch")
penny_lunch_config.add_config(:avo_password, "pennylunch")
