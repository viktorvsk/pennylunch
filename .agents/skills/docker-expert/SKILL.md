---
name: docker-expert
description: >
  Use for Docker and Docker Compose work: Rails containerization, Dockerfile review or refactor,
  .dockerignore tuning, Compose service design, health checks, volumes, networks, secrets, configs,
  build caching, image size reduction, and production hardening. In this repo, apply Rails 8,
  PostgreSQL, Propshaft, Importmap, Tailwind, Solid Queue/Cache, Puma, and Thruster conventions.
  When refactoring Compose or making it self-contained, use top-level Compose configs with files
  under docker/ referenced from docker-compose.yml.
---

# Docker Expert

Use this skill to produce production-quality Docker and Docker Compose changes. Ground every recommendation in the current repository before editing.

## Workflow

1. Inspect the actual container surface:
   - `Dockerfile*`
   - `.dockerignore`
   - `docker-compose*.yml` and `docker-compose*.yaml`
   - `docker/`
   - `Gemfile`, `Gemfile.lock`, `.ruby-version`
   - `bin/docker-entrypoint`, `bin/thrust`, `config/database.yml`, `config/puma.rb`, `config/routes.rb`
   - package manager files only if the app actually has an npm/bun/yarn/pnpm workflow.
2. Classify the task:
   - Rails app image
   - Compose service orchestration
   - Self-contained local dependency service
   - Development workflow
   - Production hardening
   - Build/cache/size optimization
   - Security review
3. Preserve established Rails conventions unless there is a concrete defect:
   - Ruby version comes from `.ruby-version`.
   - Generated Rails production Dockerfile patterns are valid starting points.
   - Propshaft, Importmap, and `tailwindcss-rails` usually do not require Node.
   - `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` is the correct production-build pattern when credentials are unavailable at build time.
   - `bin/docker-entrypoint` may run `db:prepare` before Rails server startup.
   - `bin/thrust ./bin/rails server` is the default production command when Thruster is installed.
4. Make targeted, complete changes. Do not add parallel legacy paths, duplicate Compose variants, or unused Docker stages.
5. Validate with the narrowest meaningful commands:
   - `docker compose config`
   - `docker build --check .` when available
   - `docker build -t <name>:validation .`
   - `docker compose up --build` for runtime changes
   - app health endpoint such as `/up`
6. If validation cannot run, state the exact missing dependency or environmental blocker.

## Rails Dockerfile Rules

Use a multi-stage build for production Rails images:

- `base` stage: runtime OS packages only.
- `build` stage: compilers, headers, git, and package-manager tooling needed to install gems and build assets.
- final stage: runtime packages, installed bundle, precompiled app, non-root user, entrypoint, health-compatible command.

Rails-specific checks:

- Keep `ARG RUBY_VERSION` synchronized with `.ruby-version`.
- Copy `Gemfile` and `Gemfile.lock` before the rest of the app to preserve bundle cache.
- Copy vendored gems or local gem paths only if the repo uses them.
- Remove Bundler caches and `.git` directories from installed gems in the same layer as `bundle install`.
- Precompile Bootsnap for gems and app code when Bootsnap is present.
- Precompile assets in build stage, not at runtime.
- Do not install Node/Yarn just because Tailwind is present. Check whether the app uses `tailwindcss-rails`, importmap, or a real JS package workflow.
- Include runtime packages required by Rails features: `postgresql-client` for PostgreSQL, `libvips` for Active Storage variants, `libjemalloc2` when configured.
- Run as a non-root user in the final stage.
- Expose the port the runtime actually listens on. Rails generated Dockerfiles with Thruster commonly expose `80`.

## Compose Rules

Use Compose for local development, local dependencies, and simple self-contained services. Do not hide production orchestration problems inside Compose if the target platform is Kamal, ECS, Kubernetes, Fly, Render, or another runtime.

Compose conventions:

- Prefer `docker compose` v2 commands in documentation and validation.
- Do not add the obsolete top-level `version:` key.
- Use named volumes for durable database/cache/model data.
- Use bind mounts for development source code only.
- Use explicit health checks for services that other services depend on.
- Use `depends_on: condition: service_healthy` only where Compose support is acceptable for the workflow.
- Keep internal-only services off host ports unless local access is required.
- Use service DNS names on the Compose network rather than `localhost` between containers.
- Avoid `container_name` unless an external integration strictly requires stable names.
- In PennyLunch Compose, do not add database wait loops, SQL bootstrap code, or PostgreSQL init scripts unless the user explicitly asks for them. Use service health checks, `depends_on: condition: service_healthy`, official Postgres ENV, and Rails `db:prepare`.

## Compose Configs Rule

When refactoring `docker-compose.yml`, extracting large inline content, or making a Compose setup self-contained, use top-level Compose `configs` with files stored under `docker/`.

Do this:

```yaml
services:
  ingredient-detector-http:
    image: python:3.11-slim
    configs:
      - source: ingredient_detector_start
        target: /usr/local/bin/start-ingredient-api
        mode: 0555
      - source: ingredient_detector_requirements
        target: /opt/ingredient-api/requirements.txt

configs:
  ingredient_detector_start:
    file: ./docker/ingredient-detector/start-ingredient-api.sh
  ingredient_detector_requirements:
    file: ./docker/ingredient-detector/requirements.txt
```

Do not leave large scripts, Python apps, JSON configs, nginx configs, or requirements files under `configs.*.content` in `docker-compose.yml`. Inline `content:` is acceptable only for tiny values where a separate file would reduce clarity.

Storage rules:

- Put Compose-backed config files under `docker/<service-or-purpose>/`.
- Name files by their mounted purpose, such as `start-ingredient-api.sh`, `requirements.txt`, `ingredients_config.json`, `nginx.conf`, or `puma.rb`.
- Reference them from top-level `configs` using relative `file: ./docker/...` paths.
- Keep executable scripts executable in the container with `mode: 0555` when mounted as configs.
- Treat configs as non-secret. Use Compose `secrets` or runtime environment injection for credentials, keys, tokens, and passwords.
- Keep `docker-compose.yml` as orchestration, not as a file store.

## Rails Compose Patterns

For a Rails app service:

```yaml
services:
  web:
    build:
      context: .
    environment:
      RAILS_ENV: production
      RAILS_LOG_TO_STDOUT: "1"
      RAILS_SERVE_STATIC_FILES: "1"
      DATABASE_URL: postgres://postgres:postgres@db:5432/pennylunch_production
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY:?RAILS_MASTER_KEY is required}
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "3000:80"
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1/up || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: pennylunch_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d pennylunch_production"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

Add `build.target` only when the Dockerfile defines a named stage for the intended runtime. Adapt the port, database name, and environment to the actual repo. Do not paste this blindly.

Solid Queue guidance:

- If `config/puma.rb` has `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`, setting `SOLID_QUEUE_IN_PUMA=true` can be acceptable for local development or simple deployments.
- For production scale or failure isolation, use a separate worker service with the same image and a command such as `bin/rails solid_queue:start`, after verifying the app's Rails/Solid Queue version supports that command.
- Do not run multiple independent job processors accidentally.

## Self-Contained Dependency Services

For support services that are not worth a custom image yet, Compose may mount app code, scripts, requirements, and JSON through file-backed configs under `docker/`.

Use this pattern for:

- local ML/model HTTP services
- mock APIs
- nginx or reverse-proxy configs
- service bootstrap scripts
- one-off local infrastructure adapters

Avoid this pattern when:

- the service is production-critical and should have a repeatable image build
- startup installs heavy dependencies on every new volume or platform
- files contain secrets
- the config is large enough that it deserves its own Dockerfile and build context

## Security Rules

- Never copy `config/master.key`, credentials keys, `.env`, SSH keys, API tokens, or cloud credentials into images.
- Keep secret values out of Dockerfile `ARG`, Dockerfile `ENV`, Compose `configs`, and committed Compose files.
- Prefer runtime environment variables, Compose `secrets`, platform secrets, or Rails credentials as appropriate.
- Use non-root users in runtime images.
- Keep package installs minimal and use `--no-install-recommends` for Debian-based images.
- Clean apt caches in the same `RUN` layer as package installation.
- Scan images when tooling is available, but do not block useful local work solely because Scout/Trivy is unavailable.

## Review Checklist

Dockerfile:

- [ ] Ruby version matches `.ruby-version`.
- [ ] Build and runtime stages are separated.
- [ ] Dependency files are copied before app source.
- [ ] Runtime image excludes build tools and package-manager caches.
- [ ] Assets are precompiled in the image build.
- [ ] Final image runs as non-root.
- [ ] Entrypoint and command match Rails/Thruster/Puma reality.

Compose:

- [ ] `docker compose config` passes.
- [ ] Long config/script/app content lives under `docker/` and is referenced through top-level `configs`.
- [ ] Configs are not used for secrets.
- [ ] Services have appropriate health checks.
- [ ] Volumes are named and intentional.
- [ ] Host ports are exposed only when needed.
- [ ] Service-to-service URLs use Compose DNS names.
- [ ] Rails, worker, and database startup order is health-gated where needed.

Development:

- [ ] Bind mounts do not hide installed dependencies in the container.
- [ ] File watcher polling is configured only when needed.
- [ ] Debug ports are opt-in.
- [ ] Development services do not leak into production Compose defaults.

## Handoff Boundaries

Recommend a more specific skill or expert when the task is primarily:

- Kubernetes manifests, pods, services, ingress, or Helm.
- GitHub Actions, CI cache keys, or deployment workflow design.
- Cloud-specific ECS/Fargate/App Runner/Fly/Render/Kamal deployment.
- Database backup/restore, replication, or production persistence strategy.
- Application performance tuning inside Ruby/Rails code.
