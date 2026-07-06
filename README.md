# PennyLunch

PennyLunch helps home cooks find dinner recipes they can prepare with ingredients they already have.
The app imports recipes from the PennyLane gzip source, builds a reviewed ingredient catalog, and
supports recipe search by title, category, quick/popular shortcuts, selected ingredients, and relevance-aware sorting.

## Stack

- Rails 8.1 monolith with PostgreSQL, pgvector, Solid Cache, Solid Queue, Turbo 8, Stimulus, Tailwind, Basecoat UI, Avo, and Foreman.
- Ingredient parsing runs through the pinned Python parser in `.venv`; embedding search uses Informers; ingredient photo reading uses OpenRouter.
- Production is packaged with the `Dockerfile`; local development runs Rails on the host and PostgreSQL in Docker.

## Local Development

Start application with:

```bash
docker compose up db
bin/setup --skip-server
bin/dev
```

Test using `bin/check` (RuboCop, Flay, Flog, Reek, Brakeman, Bundler Audit, ENV access, production boot, and RSpec)

## Deployment

Export next variables first: `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, `PENNY_LUNCH_DATABASE_PASSWORD`, `AVO_USERNAME`, `AVO_PASSWORD`, and `OPENROUTER_API_KEY`.
Then  run `docker compose up` - this will spin up a http web service on port 3000 by default, SSL is out of scope of this guide.

## Configuration

Application settings are centralized in `Rails.application.config.penny_lunch` via `config/initializers/penny_lunch_configuration.rb`.
Every environment variable read by app, config, or bin code must be listed in `env.example`; `bin/linters/env_access` enforces this.
This is a very simple implementation of Rails 8.2 new feature - Rails.app.creds.
See `env.example` for a comprehensive list of ENV variables.

## Rails.cache usage

- `search_strategy`: stores the active ingredient-search strategy set from Avo. `vector` enables vector search; any missing or non-`vector` value uses overlap search.
- `ingredients/catalog_metadata/v2`: stores the canonical Ingredient and alias lookup used to display parsed ingredients and resolve parser output. Ingredient changes delete this key.
- `ingredients/filterable_lookup_map`: stores the non-optional Ingredient and alias lookup used by recipe indexing. Ingredient changes delete this key.
- `["recipes/catalog/v1", Ingredient.all.cache_key_with_version, Recipe.all.cache_key_with_version]`: stores the recipe UI catalog payload for ingredient options and category labels/slugs. The key changes automatically when Ingredients or Recipes change.

## rspec --format documentation

```
Recipes
  applies title, quick, popular, and selected sort filters
  renders only recipe results for Turbo frame requests
  shows similar recipes ordered by real vector relevance
  suggests one existing category from an empty filtered result
  shows a recipe detail page with parsed ingredients and basket actions
  uses infinite scrolling when more recipes are available
  filters recipes through a category path
  keeps explicit ingredient params ahead of cookie ingredients
  shows an empty index without categories
  returns 404 when a category path is missing from the catalog
  returns 404 when a category query parameter is missing from the catalog
  shows mixed recipes without a category heading when category is absent
  uses enabled cookie ingredients for the first index render
  can use real embedding vectors for ingredient search
  shows a recipe by trailing id when the friendly URL text is stale
  does not show similar recipes for an unindexed recipe
  filters recipes through a category query parameter
  filters recipes by selected ingredients and shows readiness

IngredientParser
  returns normalized names and parser details from the real Python parser
  normalizes blank and repeated parser names across ingredient lists

BootstrapIngredientsJob
  upserts ingredients from the manual alias catalog
  uses normalized names, aliases, and boolean optional values in the real alias catalog

IndexRecipeJob
  clears stale vectors and stale joins when no required catalog ingredient is matched
  indexes all recipes from their raw ingredient lines
  indexes selected recipes with real parser output, vectors, and catalog joins

RecipeImport
  fails before writing when recipes already exist
  rejects a source payload that is not a recipe array
  rejects recipe records with invalid source shape
  rejects duplicate source identities
  imports recipes and leaves derived indexing fields empty

LocalEmbedding
  returns real finite vectors from the local embedding model
  places related ingredient text closer than unrelated ingredient text
```
