# Development Workflow

PennyLunch uses Rails binstubs for local setup, development, tests, and quality checks.

## Setup

Run:

```bash
bin/setup --skip-server
```

Use `bin/setup` without `--skip-server` to prepare the app and start the development processes. Use `bin/setup --reset --skip-server` to reset local databases before preparing them. `--reset` is blocked in production.

Setup installs Ruby gems and the pinned Python ingredient-parser dependencies into `.venv`. It also warms the parser's local NLTK data so the first recipe indexing run does not need a parser bootstrap download.

## Development

Run:

```bash
docker compose up db
bin/dev
```

`bin/dev` starts Foreman with `Procfile.dev`:

- `web`: Rails server
- `css`: Tailwind watcher in always mode
- `jobs`: Solid Queue worker. In development, `bin/jobs` defaults to async supervisor mode.

The default port is `3000`. Override it with `PORT`.

Rails runs on the host in development. PostgreSQL runs in Docker through the shared Compose file. See [Deployment](deployment.md) for the service defaults.

`docker compose up db` creates the primary production database through official Postgres environment variables. `bin/setup --skip-server` prepares the Rails development databases afterward.

## Recipe Data

Open `/avo` after starting the app. Local defaults are username `pennylunch` and password `pennylunch`.

Run these Avo actions in order:

1. In `/avo/resources/recipes`, select all recipes and run `Delete selected recipes`; then in `/avo/resources/ingredients`, select all ingredients and run `Delete selected ingredients`.
2. In `/avo/resources/recipes`, run standalone `Import recipes` with the recipe source `url`.
3. Review and complete `config/ingredient_aliases.yml`.
4. In `/avo/resources/ingredients`, run standalone `Bootstrap ingredients`.
5. In `/avo/resources/recipes`, select all recipes and run `Index selected recipes`.

The import stores source recipe fields only. It leaves `recipes.ingredient_names`, `recipes.ingredient_parse_data`, and `recipes.ingredients_vector` empty until recipe indexing. The catalog bootstrap reads `config/ingredient_aliases.yml` and upserts Ingredient records from that reviewed catalog. Optional ingredients are declared in the catalog for low-signal pantry items such as salt, sugar, water, and general cooking oils. Use Avo for small local edits and destructive local resets, but keep repository-owned bulk decisions in the YAML file. The recipe index job parses source ingredient lines, stores normalized parser names in `recipes.ingredient_names`, stores structured parser output with normalized parser name text in `recipes.ingredient_parse_data`, generates vectors from non-optional canonical Ingredient names, and recomputes `RecipeIngredient` associations in the same database transaction as the indexed recipe writes. After catalog-only changes, run `Index selected recipes` for affected or all recipes when `RecipeIngredient` rows and vectors must reflect the new catalog.

All import, indexing, catalog bootstrap, and search-strategy actions enqueue Solid Queue jobs. Keep the `jobs` process running with `bin/dev`, or run `bin/jobs`, before using those actions.

Ingredient search uses overlap matching unless `Set recipe search strategy` stores `vector` in the runtime cache. Run that action with `strategy` set to `vector` to enable vector search, or `overlap` to delete the cache key and return to overlap search.

In `/avo/resources/ingredients`, `Delete selected ingredients` removes Ingredient rows and their `RecipeIngredient` associations. If the catalog should be loaded from a clean slate, delete Ingredients in Avo first, then run `Bootstrap ingredients` and `Index selected recipes` for affected or all recipes.

The import action only queues when the `recipes` table is empty. Use the Avo recipe delete action locally if you need to repeat the MVP import before staging upsert support exists. When catalog logic changed and both tables should be rebuilt, delete recipes first and ingredients second in Avo.

## RSpec

Run the test suite single-threaded:

```bash
bin/rspec
```

Coverage is enabled by the coverage linter, not by default test runs.

Run real Informers relevance smoke specs explicitly when needed:

```bash
RUN_EMBEDDING_SPECS=1 bin/rspec spec/queries/recipe_ingredient_filter_query_spec.rb
```

## Checks

Run the full fixed quality suite:

```bash
bin/check
```

`bin/check` runs RuboCop, Flay, Flog, Reek, Brakeman, Bundler Audit, ENV access, production boot, coverage, and RSpec. Checks that share the test database run serially. It does not accept task-selection flags. For focused work, run a specific script under `bin/linters/`.

## System Specs

Capybara system specs live under `spec/system` and run with RSpec, including through `bin/check`. They use Selenium headless Chrome for Rails-native end-to-end coverage of critical Turbo flows.

Run them directly with:

```bash
bin/rspec spec/system
```

## Browser Checks

Install the browser-test dependency once:

```bash
npm install
```

With the app already running on the default development port, run:

```bash
npm run browser:smoke
```

Run the critical Turbo filter flow with:

```bash
npm run browser:filter
```

Run both browser checks with:

```bash
npm run browser:e2e
```

The browser checks reuse `http://127.0.0.1:3000` by default and do not start Rails. Set `PENNYLUNCH_BASE_URL` when the active app is on a different port, and `PLAYWRIGHT_CHROME_EXECUTABLE` when Chrome is installed outside the default macOS path. `browser:smoke` covers index-to-show navigation, show-page layout, shared basket FAB rendering, and exact basket-ingredient highlighting on index and show pages. `browser:filter` seeds and cleans up deterministic `E2E Turbo Filter` records, drives title, category, quick, and popular filters through the real browser UI, verifies the Turbo-updated results include the relevant recipe while excluding irrelevant recipes, and checks that Basecoat toolbar icon controls still open after Turbo history restoration. If system Chrome is unavailable, run `npm run browser:install` once to install Playwright's Chromium browser.

## JavaScript

PennyLunch loads application JavaScript through Rails importmap. Stimulus controllers live under `app/javascript/controllers`, shared UI modules live under `app/javascript/lib`, and `config/importmap.rb` pins both directories. Custom app behavior should not be added under `app/assets/javascripts`; that path is reserved for vendored assets when needed.

## Environment Variables

Every environment variable directly read by app, config, or bin code must be listed in `env.example`. `bin/linters/env_access` enforces this and also blocks direct ENV reads outside boot, config, bin scripts, and the central configuration loader.

Application code reads configuration from `Rails.application.config.penny_lunch`. See [Configuration](configuration.md).
