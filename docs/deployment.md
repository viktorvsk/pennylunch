# Deployment

PennyLunch keeps a production final image in `Dockerfile`, and uses `docker-compose.yml` for a source-mounted
development runtime.

Build the final production image directly with:

```bash
docker build -t penny_lunch:production .
```

The Compose stack starts:

- `web`: the `dev-runtime` image target with Rails running through `bin/dev` on host port `3000`.
- `db`: PostgreSQL 18 with pgvector for the Rails development primary and queue databases.

Override the public HTTP port with `PENNY_LUNCH_HTTP_PORT`.

## Source-Mounted Deployment
The `web` service carries `fibe.gg/*` labels that route it at the deployment root domain and run it as a source-mounted
service. Because it uses `fibe.gg/production: "false"`, Rails must run with `RAILS_ENV=development` and the development
process (`bin/dev`) so code reloads from the mounted checkout.

Launch from the local Compose file after pushing `main`. The deployment runtime receives the Compose content, then uses
the embedded `fibe.gg/repo_url` and `fibe.gg/branch` labels to clone the pushed GitHub source on the remote host. That
keeps the deployment path aligned with later GitHub webhook source sync.

The launch should create a long-running environment named for the app, target the deployment root domain, persist
volumes, and route the `web` service at the root subdomain.

Static crawl assets live in `public/robots.txt` and `public/sitemap.xml`. Because the sitemap is a checked-in static
file, its URLs use the default local base URL until a canonical production hostname is committed or sitemap generation
moves into Rails. Replace the sitemap host with the deployment root domain before relying on public search indexing.

Pass these env overrides during launch and keep the same values in the remote operator-only recovery notes:

- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `PENNY_LUNCH_DATABASE_PASSWORD`
- `AVO_USERNAME`
- `AVO_PASSWORD`
- `OPENROUTER_API_KEY`
- `PENNYLUNCH_BASE_URL`

The GitHub repository webhook should point to the deployment runtime's GitHub webhook endpoint with the shared
`GITHUB_WEBHOOK_SECRET`. Because the service uses `fibe.gg/production: "false"`, clean pushes sync the mounted checkout
and refresh runtime state automatically.

The same `db` service is used for source-mounted runtime and local development. Development defaults are
intentionally usable without secrets; remote deployments should set `PENNY_LUNCH_DATABASE_PASSWORD`, `SECRET_KEY_BASE`,
and Avo credentials before starting the full stack.

The Compose-managed PostgreSQL service uses the application database user as the official Postgres bootstrap user.
`POSTGRES_DB` creates the primary development database, and Rails `db:prepare` creates the additional queue database
because that bootstrap user is privileged inside this self-contained Compose stack.

PostgreSQL loads an inline Compose `postgres_config` config. The settings are conservative for a small shared host and
take effect on the next `db` container restart.

If a local Compose volume was initialized with older database defaults, recreate that volume before using these defaults.

The source-mounted web process runs `bin/dev`, which starts Rails, Tailwind watch, and Solid Queue jobs through
`Procfile.dev`.

`PENNY_LUNCH_DATABASE_MAX_CONNECTIONS` defaults to `5` in Compose so the Solid Queue process has enough queue database
connections while Puma runs with three request threads.

`bin/setup` installs Python dependencies into `/rails/.venv`, installs the pinned `ingredient-parser-nlp` dependency from
`requirements.txt`, and warms the local NLTK parser data. The image puts `/rails/.venv/bin` first on `PATH`, so Rails
invokes the parser with `python /rails/libexec/parse_ingredients.py`; Compose only sets `NLTK_DATA` for the parser data
directory.

Persistent data lives in named Docker volumes:

- `postgres_data`: PostgreSQL data.
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
