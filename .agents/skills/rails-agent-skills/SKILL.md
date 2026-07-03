---
name: rails-agent-skills
description: >
  Use for Ruby on Rails work in this repo: Rails 8.1 implementation, refactoring, RSpec/TDD,
  Active Record models and queries, controllers, Hotwire/Turbo/Stimulus, Rails views, migrations,
  service objects, background jobs with Solid Queue, security review, and Rails code review.
  Provides a self-contained Rails workflow and routes to local skills such as rails-expert,
  solid-queue-setup, basecoat-ui, docker-expert, and grill-with-docs when relevant.
---

# Rails Agent Skills

Use this as the operating playbook for Rails changes in PennyLunch. It is self-contained; do not assume missing atomic skills, `directory.json`, or an external skill router exists.

## Repo Defaults

Treat the current app as:

- Rails 8.1 monolith.
- PostgreSQL through `pg`.
- Propshaft, Importmap, Turbo, Stimulus, and `tailwindcss-rails`.
- RSpec with `rspec-rails`, `shoulda-matchers`, `factory_bot_rails`, `faker`, and `webmock`.
- Solid Cache and Solid Queue.
- Puma and Thruster for production runtime.
- Product domain: helping users find relevant dinner recipes from ingredients they have at home.

Verify these facts from files before relying on them; the repo can change.

## Skill Routing

Use these local skills when the task crosses their scope:

- `rails-expert`: detailed Rails implementation, Active Record, Hotwire, RSpec, APIs, and jobs. Load only the relevant reference file.
- `solid-queue-setup`: Solid Queue configuration, job design, queue setup, recurring jobs, and job specs.
- `basecoat-ui`: Rails/ERB/Turbo UI with Basecoat components and product UI polish.
- `docker-expert`: Rails Dockerfile, Docker Compose, service configs, and container hardening.
- `grill-with-docs`: ambiguous architecture, domain, migration, or rollout decisions that need pressure-testing and ADR/glossary updates before code.

Do not use `find-skills` unless local skills are insufficient and the user wants external skill discovery or installation.

## Context First

Before implementation or review, inspect the smallest useful slice:

1. `Gemfile`, `.ruby-version`, and relevant config.
2. `config/routes.rb`.
3. `db/schema.rb` or migrations when data is involved.
4. Nearby models, controllers, jobs, services, views, helpers, Stimulus controllers, and specs.
5. Existing naming, error handling, validations, authorization, and response patterns.
6. Current test setup. If specs are not configured yet, make test setup part of the task before relying on RSpec.

State important assumptions when local context is missing.

## TDD And Validation

Default to behavior-first changes:

1. Plan the smallest set of specs that prove the behavior.
2. Write or update a focused failing spec before implementation for user-visible behavior, domain logic, jobs, services, model validations, and controller/request behavior.
3. Run the targeted spec and confirm it fails for the expected reason.
4. Implement the change.
5. Re-run the targeted spec until it passes.
6. Run adjacent validation proportional to risk: related specs, `bin/rubocop`, `bin/brakeman`, browser checks, or `bin/rails db:migrate`.

Reasonable exceptions to strict test-first:

- Documentation or skill edits.
- Mechanical renames with no behavior change.
- Generated setup where the first useful validation is booting or running the generator.
- Exploratory diagnosis before a reproducible bug is known.
- Pure UI styling where browser verification is more meaningful than a unit spec.

When skipping test-first, explain why and still verify the result.

## RSpec, FactoryBot, And Faker

If `spec/` does not exist yet, set up RSpec before relying on tests:

```bash
bin/rails generate rspec:install
```

RSpec rules:

- Require `rails_helper` for Rails specs. Use `spec_helper` only for pure Ruby code that intentionally avoids Rails boot.
- Run the smallest useful target first: `bundle exec rspec spec/path/file_spec.rb` or `bundle exec rspec spec/path/file_spec.rb:42`.
- Write examples around behavior, not private implementation details.
- Use `subject(:result)` for the action under test and descriptive `let` names for inputs.
- Use `let!` only when creation order or eager persistence matters.
- Use `aggregate_failures` only for multiple expectations about the same behavior.
- Use `travel_to` for time-dependent behavior and Active Job test helpers for enqueueing.
- Avoid `allow_any_instance_of`; inject collaborators or stub boundary objects.
- Do not add `database_cleaner`, `simplecov`, Selenium, Devise helpers, or authentication helpers unless the Gemfile and app actually have them.

FactoryBot rules:

- Factories live under `spec/factories`.
- Keep default factories minimal and valid. Add optional state with traits.
- Use `build` for validations and pure object behavior, `build_stubbed` for persisted-looking objects that do not hit the database, and `create` only when persistence, queries, callbacks, constraints, or associations are part of the behavior.
- Use sequences for unique fields. Do not rely on random fake data for uniqueness.
- Keep associations explicit when they matter to the example.
- Use `transient` attributes and `after(:create)` only in traits that clearly request associated records.

Faker/FFaker rules:

- Inspect `Gemfile` before writing factories. This repo currently uses `faker`, so use the `Faker::` namespace.
- If the repo later switches to `ffaker`, use the `FFaker::` namespace. Do not mix `Faker::` and `FFaker::`.
- Do not add `ffaker` just because a prompt says "ffaker"; add or switch gems only when the user asks for that dependency change.
- Use fake data for plausible defaults, not for asserted values. If a spec checks a value, set that value explicitly in the example.
- Prefer stable domain literals for PennyLunch examples: ingredient names, recipe names, cooking times, and match counts should be understandable and deterministic.

## Rails Implementation Rules

Controllers:

- Keep controllers thin: load resources, authorize, call domain/application code, choose response.
- Use strong parameters and explicit HTTP statuses.
- For invalid form submissions, render with `status: :unprocessable_entity`.

Models and data:

- Put invariants close to the data with database constraints where possible.
- Add indexes for foreign keys and query-critical columns.
- Avoid callbacks for cross-system side effects unless the lifecycle coupling is intentional.
- Avoid raw SQL unless parameterized and justified.
- Check collection queries for N+1 risks and use `includes`, `preload`, or `eager_load` intentionally.

Services and domain code:

- Add a service object only when it reduces controller/model complexity or expresses a real application operation.
- Prefer plain Ruby objects under `app/services` or a domain-specific folder.
- Keep return contracts explicit. Do not invent a framework-wide service abstraction unless repeated usage justifies it.

Migrations:

- Keep migrations deployable with the current app boot path.
- Separate risky data backfills from schema changes when needed for uninterrupted deployment.
- Do not silently change destructive semantics. If data loss is intentional, document it.
- Verify with `bin/rails db:migrate` and, when possible, `bin/rails db:rollback`.

Background jobs:

- Use Active Job and Solid Queue unless the repo intentionally adds another backend.
- Jobs should be idempotent enough for retries.
- Use `discard_on` for permanently missing records and `retry_on` for transient external failures.
- Keep slow external calls out of request cycles.

Views and Hotwire:

- Use server-rendered ERB and Turbo first.
- Use Stimulus for small client behavior.
- Use Basecoat through `basecoat-ui` for component markup and UI quality.
- Verify Turbo Frame/Stream replacement and browser back/forward behavior for interactive flows.

## Testing Map

Choose the spec type that proves behavior with the least friction:

- Model spec: validations, associations, scopes, query methods, domain invariants.
- Service spec: application operation, branching rules, integration boundaries with fakes.
- Request spec: routes, params, redirects, status codes, authentication/authorization, Turbo Stream responses.
- System spec: critical browser flows, Hotwire behavior, forms, and Basecoat UI interactions.
- Job spec: enqueueing, queue name, retry/discard behavior, idempotent `perform`.
- Migration check: schema changes, indexes, constraints, and rollback safety where applicable.

Use factories for persisted records. Use WebMock for external HTTP. Avoid brittle tests that assert private implementation details.

## Review Checklist

Before finishing Rails work:

- [ ] Routes, schema/migrations, and nearby patterns were inspected.
- [ ] User-facing behavior is covered by focused specs or a justified browser/manual check.
- [ ] Targeted specs pass.
- [ ] N+1 risks and missing indexes were considered.
- [ ] Strong parameters, authorization/authentication, and error statuses are correct.
- [ ] Background work is idempotent and not accidentally duplicated.
- [ ] Turbo/UI behavior was checked when views changed.
- [ ] User-facing text does not leak internal implementation details.
- [ ] Relevant docs, ADRs, tradeoffs, or skills were updated when behavior or workflow changed.

## Useful Commands

```bash
bin/rails routes
bin/rails db:migrate
bin/rails db:rollback
bundle exec rspec <spec_path>
bin/rubocop
bin/brakeman
bin/bundler-audit
```

Prefer the repo's binstubs when they exist.
