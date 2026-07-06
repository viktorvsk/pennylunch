# PennyLunch

PennyLunch helps home cooks find dinner recipes they can prepare with ingredients they already have.
The app imports recipes from the PennyLane gzip source, builds a reviewed ingredient catalog, and
supports recipe search by title, category, quick/popular shortcuts, selected ingredients, and relevance-aware sorting.

- See [Trello](https://trello.com/b/jXpg1CdU/pennylunch) for more information: user stories, scope, backlog, roadmap and more.
- App is available at https://pennylunch.viktorvsk.com/
- To access [admin](https://pennylunch.viktorvsk.com/avo) use `pennylunch/pennylunch`

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

Export these variables first: `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, `PENNY_LUNCH_DATABASE_PASSWORD`, `AVO_USERNAME`, `AVO_PASSWORD`, and `OPENROUTER_API_KEY`.
Then run `docker compose up` - this will spin up a http web service on port 3000 by default, SSL is out of scope of this guide.

## Configuration

Application settings are centralized in `Rails.application.config.penny_lunch` via `config/initializers/penny_lunch_configuration.rb`.
Every environment variable read by app, config, or bin code must be listed in `env.example`; `bin/linters/env_access` enforces this.
See `env.example` for a comprehensive list of ENV variables.

## Rails.cache usage

- `search_strategy`: stores the active ingredient-search strategy set from Avo. `vector` enables vector search; any missing or non-`vector` value uses overlap search.
- `ingredients/catalog_names/v1`: stores ordered canonical Ingredient names used for image ingredient detection. Ingredient changes delete this key.
- `ingredients/catalog_metadata/v3`: stores the canonical Ingredient and alias lookup used to display parsed ingredients and resolve parser output. Ingredient changes delete this key.
- `ingredients/filterable_lookup_map`: stores the non-optional Ingredient and alias lookup used by recipe indexing. Ingredient changes delete this key.
- `["recipes/catalog/v1", Ingredient.all.cache_key_with_version, Recipe.all.cache_key_with_version]`: stores the recipe UI catalog payload for ingredient options and category labels/slugs. The key changes automatically when Ingredients or Recipes change.

# User Stories

Detailed user stories (and more are available at [Trello](https://trello.com/b/jXpg1CdU/pennylunch)), but adding 2 of them here just for the sake of meeting requirements in the README.md :)

## Import Raw Recipes

We need to be able to import raw Recipes from a JSON file as an admin.
We will first implement general service to achieve that without admin UI.

Initial data is located at https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz
This is a ~1MB .gz file that restores into ~6MB JSON.
We need to get the file, unzip, read as JSON, convert into CSV and store in the database quickly, without modifications.

- Create Recipe model that matches basic attributes of raw data
- Use Postgres COPY to import CSV directly into recipes table

**Deliverables**: RecipeImport service that populates Recipe model with raw data


## Basic UI

Now that we have Recipe imported into the system we need very basic index and show pages to overview them. We also need some very basic filters at this stage.

- Create /recipes and /recipes/:slug pages
- Generate SEO and human friendly slug based on Recipe  data
- On show page keep things very simple - image and ingredients list
- On index page show infinite scroll of all of the Recipes at first
- Allow to filter recipes by:
  - Quick: shortcut that finds those which total time < X
  - Popular: shortcut that finds those with rating > Y
  - Allow sort by quick, slow, popular, unpopular
  - Category (we need basic normalization for that)
  - Title (use Postgres FTS for simplicity)

Use Turbo for seamless navigation.

**Deliverables**: /recipes and /recipes/:slug pages + functional search
