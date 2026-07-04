# Deployment

PennyLunch keeps a production final image in `Dockerfile`, and uses `docker-compose.yml` for the fibe-distilled
source-mounted runtime.

Build the final production image directly with:

```bash
docker build -t penny_lunch:production .
```

The Compose stack starts:

- `web`: the `fibe-dev` image target with Rails running through `bin/dev` on host port `3000`.
- `db`: PostgreSQL 18 with pgvector for the Rails development primary and queue databases.

Override the public HTTP port with `PENNY_LUNCH_HTTP_PORT`.

## fibe-distilled Deployment

The Compose file is launchable through fibe-distilled. The `web` service carries `fibe.gg/*` labels that route it at the
Marquee root domain and run it as a source-mounted service. Because it uses `fibe.gg/production: "false"`, Rails must run
with `RAILS_ENV=development` and the development process (`bin/dev`) so code reloads from the mounted checkout.

```text
https://pennylunch.viktorvsk.com
```

The fibe-distilled API is expected to stay private on the remote host. Use a local SSH tunnel and a dedicated local Fibe
CLI profile, for example:

```bash
ssh -N -L 2402:127.0.0.1:2402 root@165.22.82.180
fibe auth login --profile pennylunch-distilled --domain http://127.0.0.1:2402 --api-key "$FIBE_API_KEY"
```

Launch from the local Compose file after pushing `main`. fibe-distilled receives the Compose content from the CLI, then
uses the embedded `fibe.gg/repo_url` and `fibe.gg/branch` labels to clone the pushed GitHub source on the remote host.
This keeps the launch path inside fibe-distilled's supported supplied-Compose API while still matching the later GitHub
webhook path.

```bash
fibe --profile pennylunch-distilled launch \
  --compose @docker-compose.yml \
  --name pennylunch \
  --marquee default \
  --create-playground \
  --persist-volumes \
  --subdomain web=@ \
  --wait \
  --wait-timeout 20m
```

Pass these env overrides during launch and keep the same values in the remote operator-only recovery notes:

- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `PENNY_LUNCH_DATABASE_PASSWORD`
- `AVO_USERNAME`
- `AVO_PASSWORD`
- `OPENROUTER_API_KEY`
- `PENNYLUNCH_BASE_URL=https://pennylunch.viktorvsk.com`

The GitHub repository webhook should point to `https://pennylunch.viktorvsk.com/webhooks/github` with the shared
`GITHUB_WEBHOOK_SECRET`. Because the service uses `fibe.gg/production: "false"`, clean pushes sync the mounted checkout
and refresh runtime state automatically.

The same `db` service is used for the Fibe source-mounted runtime and local development. Development defaults are
intentionally usable without secrets; remote deployments should set `PENNY_LUNCH_DATABASE_PASSWORD`, `SECRET_KEY_BASE`,
and Avo credentials before starting the full stack.

The Compose-managed PostgreSQL service uses the application database user as the official Postgres bootstrap user.
`POSTGRES_DB` creates the primary development database, and Rails `db:prepare` creates the additional queue database
because that bootstrap user is privileged inside this self-contained Compose stack.

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
