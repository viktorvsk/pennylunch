# Deployment

PennyLunch ships a production-default Docker Compose setup for a single-host deployment.

Run production with:

```bash
export PENNY_LUNCH_DATABASE_PASSWORD="$(openssl rand -hex 32)"
export SECRET_KEY_BASE="$(openssl rand -hex 64)"
docker compose up --build --pull always
```

The default stack starts:

- `web`: the Rails production image behind Thruster on host port `3000`.
- `db`: PostgreSQL 18 with pgvector for the Rails primary, cache, and queue databases.

Override the public HTTP port with `PENNY_LUNCH_HTTP_PORT`.

The same `db` service is used in development and production. Development defaults are intentionally usable without secrets; production deployments must set `PENNY_LUNCH_DATABASE_PASSWORD`, `SECRET_KEY_BASE`, and maintenance task credentials before starting the full stack.

The Compose-managed PostgreSQL service uses the application database user as the official Postgres bootstrap user. `POSTGRES_DB` creates the primary production database, and Rails `db:prepare` creates the additional queue and cache databases because that bootstrap user is privileged inside this self-contained Compose stack.

If a local Compose volume was initialized with older database defaults, recreate that volume before using these defaults.

The production web process runs Solid Queue inside Puma through `SOLID_QUEUE_IN_PUMA=true`. This keeps the compose deployment self-contained for the current single-server application shape.

`PENNY_LUNCH_DATABASE_MAX_CONNECTIONS` defaults to `5` in production compose so the Solid Queue supervisor has enough queue database connections while Puma runs with three request threads.

The production image installs the global `python` command, builds a Python virtualenv at `/rails/.venv`, installs the pinned `ingredient-parser-nlp` dependency from `requirements.txt`, and warms the local NLTK parser data. The image puts `/rails/.venv/bin` first on `PATH`, so Rails invokes the parser with `python /rails/libexec/parse_ingredients.py`; Compose only sets `NLTK_DATA` for the parser data directory.

Persistent data lives in named Docker volumes:

- `postgres_data`: production PostgreSQL data.
- `rails_storage`: local Active Storage files and the Informers model cache.

## Development Database

The development workflow keeps Rails on the host and PostgreSQL in Docker:

```bash
docker compose up db
bin/setup --skip-server
bin/dev
```

Targeting `db` by name starts only PostgreSQL. Rails runs on the host through `bin/dev`.

Development defaults are:

- host: `127.0.0.1`
- port: `5432`
- username: `penny_lunch`
- password: `postgres`

Override the exposed development database port with `PENNY_LUNCH_DEVELOPMENT_DATABASE_PORT`.
