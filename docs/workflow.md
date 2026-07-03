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

Open `/maintenance_tasks` after starting the app. Local defaults are username `pennylunch` and password `pennylunch`.

Run these tasks in order:

1. `Maintenance::WarmEmbeddingModelTask`
2. `Maintenance::ImportRecipesTask`
3. `Maintenance::BackfillRecipeIngredientVectorsTask`

The import task only runs when the `recipes` table is empty. Reset the local database if you need to repeat the MVP import before staging upsert support exists. The backfill task parses source ingredient lines into `ingredient_names`, stores structured `ingredient_parse_data`, and generates vectors from the names.

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

## Environment Variables

Every environment variable directly read by app, config, or bin code must be listed in `env.example`. `bin/linters/env_access` enforces this and also blocks direct ENV reads outside boot, config, bin scripts, and the central configuration loader.

Application code reads configuration from `Rails.application.config.penny_lunch`. See [Configuration](configuration.md).
