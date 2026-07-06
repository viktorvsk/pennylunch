# PennyLunch

PennyLunch helps home cooks find dinner recipes they can prepare with ingredients they already have. The app imports recipes from the PennyLane gzip source, builds a reviewed ingredient catalog, and supports recipe search by title, category, quick/popular shortcuts, selected ingredients, and relevance-aware sorting.

## Stack

- Rails 8.1 monolith with PostgreSQL, pgvector, Solid Cache, Solid Queue, Turbo 8, Stimulus, Tailwind, Basecoat UI, Avo, and Foreman.
- Ingredient parsing runs through the pinned Python parser in `.venv`; embedding search uses Informers; ingredient photo reading uses OpenRouter.
- Production is packaged with the `Dockerfile`; local development runs Rails on the host and PostgreSQL in Docker.

## Local Development

```bash
docker compose up db
bin/setup --skip-server
bin/dev
```

The app runs at `http://127.0.0.1:3000`. Recipes are at `/recipes`, and local admin is at `/avo` with default credentials `pennylunch` / `pennylunch`.

`bin/dev` starts Rails, the Tailwind watcher, and Solid Queue jobs. Keep it running before using Avo import, catalog bootstrap, indexing, or search-strategy actions.

## Recipe Data

From `/avo/resources/recipes`, run `Import recipes` with the default gzip source, then review `config/ingredient_aliases.yml`, run `Bootstrap ingredients`, and run `Index selected recipes`. Import stores source recipe fields first; indexing parses ingredient lines, stores parser output, resolves catalog ingredients, creates `RecipeIngredient` rows, and generates vectors from non-optional canonical ingredients.

Ingredient search defaults to exact overlap against canonical Ingredient names. Avo can switch the runtime strategy to vector search through the Rails cache key `search_strategy`. Optional pantry staples remain selectable and visible but do not constrain filtering or vector text.

## Configuration

Application settings are centralized in `Rails.application.config.penny_lunch` via `config/initializers/penny_lunch_configuration.rb`. Every environment variable read by app, config, or bin code must be listed in `env.example`; `bin/linters/env_access` enforces this.

Common local values include `AVO_USERNAME`, `AVO_PASSWORD`, `OPENROUTER_API_KEY`, `INGREDIENTS_MAX_COSINE_DISTANCE`, `INGREDIENT_PARSER_TIMEOUT_SECONDS`, `INFORMERS_CACHE_DIR`, `PENNYLUNCH_BASE_URL`, and the `PENNY_LUNCH_DATABASE_*` settings.

## Cache Keys

- `search_strategy`: stores the active ingredient-search strategy set from Avo. `vector` enables vector search; any missing or non-`vector` value uses overlap search.
- `ingredients/catalog_metadata/v2`: stores the canonical Ingredient and alias lookup used to display parsed ingredients and resolve parser output. Ingredient changes delete this key.
- `ingredients/filterable_lookup_map`: stores the non-optional Ingredient and alias lookup used by recipe indexing. Ingredient changes delete this key.
- `["recipes/catalog/v1", Ingredient.all.cache_key_with_version, Recipe.all.cache_key_with_version]`: stores the recipe UI catalog payload for ingredient options and category labels/slugs. The key changes automatically when Ingredients or Recipes change.

`INFORMERS_CACHE_DIR` is a filesystem model cache directory for embedding dependencies, not a Rails cache key.

## Checks

```bash
bin/rspec
bin/check
```

`bin/check` runs the fixed quality suite: RuboCop, Flay, Flog, Reek, Brakeman, Bundler Audit, ENV access, production boot, and RSpec.

## Deployment

Build the production image with:

```bash
docker build -t penny_lunch:production .
```

The supported Compose entry point is:

```bash
docker compose up --build --pull always
```

Set production secrets such as `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, `PENNY_LUNCH_DATABASE_PASSWORD`, `AVO_USERNAME`, `AVO_PASSWORD`, and `OPENROUTER_API_KEY` before running a public deployment.
