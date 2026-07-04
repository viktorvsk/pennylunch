# Configuration

PennyLunch keeps application configuration behind one Rails 8.1-compatible surface:

```ruby
Rails.application.config.penny_lunch
```

Application code must not read `ENV` or `Rails.application.credentials` directly. Add application settings in `config/initializers/penny_lunch_configuration.rb`, then read the loaded value from `Rails.application.config.penny_lunch`.

Settings resolve in this order:

1. The declared ENV override.
2. The declared default.

Blank ENV values resolve to `nil`, so deployments can unset a default explicitly.

Rails boot and runtime configuration stays in `config/` and `bin/` because Rails, Bundler, Puma, database config, CI, and setup scripts need those values before application configuration is available.

When adding a setting:

1. Add it in `config/initializers/penny_lunch_configuration.rb` with `penny_lunch_config.add_config(:name, default_value)`.
2. Add the uppercase ENV name to `env.example`.
3. Store secret defaults in Rails credentials.
4. Add or update a focused spec when the setting affects behavior.

`bin/linters/env_access` enforces this policy.

## Recipe MVP Settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `INGREDIENTS_MAX_COSINE_DISTANCE` | `0.7` | Maximum cosine distance for vector ingredient-search candidates. |
| `INGREDIENT_PARSER_TIMEOUT_SECONDS` | `120` | Timeout for each parser shell-out batch. |
| `INFORMERS_CACHE_DIR` | `storage/informers` | Persistent local model cache path. |
| `EMBEDDING_MODEL_PRELOAD` | `true` | Enables non-blocking model warmup after Rails server boot outside test. |
| `MAINTENANCE_TASKS_USERNAME` | `pennylunch` | HTTP basic username for `/maintenance_tasks` and `/avo`. |
| `MAINTENANCE_TASKS_PASSWORD` | `pennylunch` | HTTP basic password for `/maintenance_tasks` and `/avo`. |

Ingredient search strategy is controlled at runtime through the Rails cache key `search_strategy`. `Maintenance::SetRecipeSearchStrategyTask` sets the key to `vector` when its `strategy` parameter is `vector`, and deletes the key when its `strategy` parameter is `overlap`. Missing or non-`vector` cache values use overlap search.

## Python Runtime Settings

The Ruby parser wrapper runs `python` against `libexec/parse_ingredients.py`. Rails boot and Docker put `.venv/bin` first on `PATH`, so the command resolves to the parser virtualenv without a separate application setting. `NLTK_DATA` points the Python ingredient parser at its local model-data directory. Docker Compose sets it to `/rails/.venv/nltk_data`; local setup defaults to `.venv/nltk_data`.
