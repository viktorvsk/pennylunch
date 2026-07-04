# Development Workflow

PennyLunch uses Rails binstubs for local setup, development, tests, and quality checks.

## Setup

Run:

```bash
bin/setup --skip-server
```

Use `bin/setup` without `--skip-server` to prepare the app and start the development processes. Use `bin/setup --reset --skip-server` to reset local databases before preparing them. `--reset` is blocked in production.

Setup installs Ruby gems and the pinned Python ingredient-parser dependencies into `.venv`. It also warms the parser's local NLTK data so the first recipe import or ingredient search does not need a parser bootstrap download.

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

Open `/maintenance_tasks` or `/avo` after starting the app. Local defaults are username `pennylunch` and password `pennylunch`.

Run these tasks in order:

1. `Maintenance::WarmEmbeddingModelTask`
2. `Maintenance::DeleteRecipesAndIngredientsTask`
3. `Maintenance::ImportRecipesTask`
4. Review and complete `config/ingredient_aliases.yml` for any raw names reported by the next task.
5. `Maintenance::SyncIngredientsFromAliasCatalogTask`
6. `Maintenance::DeleteRecipesTask`
7. `Maintenance::ImportRecipesTask`
8. `Maintenance::BackfillRecipeIngredientVectorsTask`

The first import stores raw parser names in `recipes.ingredient_parse_data` and `recipes.ingredient_names`. The sync task reads `config/ingredient_aliases.yml`, verifies every raw parser name is covered by one alias, then recreates Ingredient records from that reviewed catalog. Optional ingredients are declared in the catalog for low-signal pantry items such as salt, sugar, water, and general cooking oils. Use Avo for small local edits, but keep repository-owned bulk decisions in the YAML file. The delete task removes only recipes, leaving Ingredients in place. The second import must keep raw parser names in `recipes.ingredient_names`, stores non-optional canonical names in `recipes.ingredients_vector_names`, and the backfill task stores structured `ingredient_parse_data` and generates vectors from those non-optional canonical names.

`Maintenance::DeleteIngredientsTask` removes only Ingredient rows. `Maintenance::ReloadIngredientsFromAliasCatalogTask` deletes current Ingredients and loads exactly `config/ingredient_aliases.yml` without checking recipe coverage; use it when debugging the catalog in Avo while recipes still exist. The strict sync task should be used for the real import/reindex loop because it refuses incomplete catalog coverage.

The import task only runs when the `recipes` table is empty. Use `Maintenance::DeleteRecipesTask` locally if you need to repeat the MVP import before staging upsert support exists, or `Maintenance::DeleteRecipesAndIngredientsTask` when catalog logic changed and both tables should be rebuilt.

## RSpec

Run the test suite single-threaded:

```bash
bin/rspec
```

Coverage is enabled by the coverage linter, not by default test runs.

Run real Informers relevance smoke specs explicitly when needed:

```bash
RUN_EMBEDDING_SPECS=1 bin/rspec spec/services/recipes/search_spec.rb
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

The browser checks reuse `http://127.0.0.1:3000` by default and do not start Rails. Set `PENNYLUNCH_BASE_URL` when the active app is on a different port, and `PLAYWRIGHT_CHROME_EXECUTABLE` when Chrome is installed outside the default macOS path. `browser:smoke` covers index-to-show navigation, show-page layout, shared basket FAB rendering, and exact basket-ingredient highlighting on index and show pages. `browser:filter` seeds and cleans up deterministic `E2E Turbo Filter` records, drives title, category, quick, and popular filters through the real browser UI, and verifies the Turbo-updated results include the relevant recipe while excluding irrelevant recipes. If system Chrome is unavailable, run `npm run browser:install` once to install Playwright's Chromium browser.

## Environment Variables

Every environment variable directly read by app, config, or bin code must be listed in `env.example`. `bin/linters/env_access` enforces this and also blocks direct ENV reads outside boot, config, bin scripts, and the central configuration loader.

Application code reads configuration from `Rails.application.config.penny_lunch`. See [Configuration](configuration.md).
