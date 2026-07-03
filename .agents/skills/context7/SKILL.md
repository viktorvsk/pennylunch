---
name: context7
description: >
  Retrieve current documentation through the Context7 API for Rails work in this repo.
  Use when Codex needs up-to-date Rails, Hotwire, RSpec, FactoryBot, Faker/FFaker,
  Solid Queue, Importmap, Propshaft, Tailwind, Basecoat, or Ruby gem API details
  before implementing, reviewing, or explaining code.
---

# Context7 For Rails

Use this skill to ground Rails work in current library documentation instead of memory. In PennyLunch, treat Context7 as a documentation lookup layer that complements local code inspection and the Rails skills; it does not replace reading the repo.

## Before Lookup

Inspect the local source of truth first:

- `Gemfile` and `Gemfile.lock` for installed gems and versions.
- `.ruby-version`, `config/application.rb`, and relevant framework config.
- Nearby app code, specs, and local skills such as `rails-agent-skills`, `rails-expert`, `basecoat-ui`, `solid-queue-setup`, and `docker-expert`.

Use Context7 when an API, option, generator, test helper, lifecycle hook, or framework behavior may have changed or needs exact confirmation.

## Search Workflow

1. Turn the task into a specific library plus topic, such as `rspec rails request specs`, `turbo rails streams`, or `factory bot traits`.
2. Search Context7 and inspect several results, not only the first result.
3. Prefer official or project-owned library IDs over generic mirrors when they cover the topic.
4. Prefer Rails adapters over framework-generic docs when Rails integration matters.
5. Fetch only the focused topic you need with `type=txt`.
6. Use the retrieved docs to make the code decision, then cite the library ID or source in your final answer when it materially affected the solution.

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=LIBRARY_NAME&query=TOPIC" \
  | jq '.results[:8] | map({id,title,description,totalSnippets})'

curl -s "https://context7.com/api/v2/context?libraryId=LIBRARY_ID&query=TOPIC&type=txt"
```

URL-encode spaces with `+` or `%20`. Use `jq` for result inspection when available.

## Rails Library Fast Paths

Verify fast paths with search when the version or exact source matters.

| Need | Prefer |
| --- | --- |
| Rails API for this repo's current Rails 8.1.3 line | `/websites/api_rubyonrails_v8_1_3` |
| Rails framework source/API breadth | `/rails/rails` |
| Rails guides and conceptual behavior | `/websites/guides_rubyonrails` |
| RSpec Rails request/model/system/job specs | `/rspec/rspec-rails` |
| Core RSpec expectations, mocks, and metadata | `/rspec/rspec` |
| FactoryBot strategies, traits, callbacks, associations | `/thoughtbot/factory_bot` |
| FactoryBot Rails integration | `/thoughtbot/factory_bot_rails` |
| Faker Ruby data generators | `/faker-ruby/faker` |
| FFaker, only if the repo actually uses `ffaker` | `/ffaker/ffaker` |
| Turbo Rails integration | `/hotwired/turbo-rails` |
| Turbo frames, streams, Drive, and events | `/websites/turbo_hotwired_dev` |
| Stimulus Rails integration | `/hotwired/stimulus-rails` |
| Stimulus controller behavior | `/hotwired/stimulus` |
| Solid Queue | `/rails/solid_queue` |
| Importmap for Rails | `/rails/importmap-rails` |
| Propshaft | `/rails/propshaft` |
| Tailwind CSS Rails | `/rails/tailwindcss-rails` |
| Basecoat UI components | `/hunvreus/basecoat` or `/websites/basecoatui_components` |

## Rails Examples

### Rails API Or Guides

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=ruby%20on%20rails&query=active%20record%20migrations%20rails%208" \
  | jq '.results[:5] | map({id,title,totalSnippets})'

curl -s "https://context7.com/api/v2/context?libraryId=/websites/api_rubyonrails_v8_1_3&query=ActiveRecord::Migration&type=txt"
```

Use API docs for exact class, method, and option signatures. Use guides for workflow-level behavior such as migrations, routing, forms, validations, or Active Job concepts.

### RSpec Rails

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=rspec%20rails&query=request%20specs%20rails" \
  | jq '.results[:5] | map({id,title,totalSnippets})'

curl -s "https://context7.com/api/v2/context?libraryId=/rspec/rspec-rails&query=request+specs&type=txt"
```

Use this before adding unfamiliar spec types, matchers, controller/request helper behavior, Active Job specs, or system specs.

### FactoryBot And Fake Data

```bash
curl -s "https://context7.com/api/v2/context?libraryId=/thoughtbot/factory_bot&query=traits+associations+sequences&type=txt"
curl -s "https://context7.com/api/v2/context?libraryId=/faker-ruby/faker&query=unique+values+email+name&type=txt"
```

This repo currently uses `faker`, so use `Faker::` in factories and specs. Use `FFaker::` only after the Gemfile switches to `ffaker`. Do not mix namespaces, and do not add or switch fake-data gems just because docs exist.

### Hotwire And Basecoat

```bash
curl -s "https://context7.com/api/v2/context?libraryId=/hotwired/turbo-rails&query=turbo+streams+rendering&type=txt"
curl -s "https://context7.com/api/v2/context?libraryId=/hotwired/stimulus-rails&query=controllers+importmap&type=txt"
curl -s "https://context7.com/api/v2/context?libraryId=/hunvreus/basecoat&query=dialog+dropdown+rails+turbo&type=txt"
```

For UI implementation, combine Context7 with the `basecoat-ui` skill. Confirm any required JavaScript reinitialization behavior after Turbo frame/stream replacement.

### Solid Queue

```bash
curl -s "https://context7.com/api/v2/context?libraryId=/rails/solid_queue&query=recurring+jobs+concurrency+controls&type=txt"
```

Use this for Active Job queue configuration, recurring tasks, concurrency controls, worker behavior, and retry/discard semantics.

## TDD Usage

During Rails TDD, use Context7 to verify the framework contract before or while writing the failing spec:

- RSpec Rails helpers and spec type behavior.
- FactoryBot strategy semantics: `build`, `build_stubbed`, `create`, traits, sequences, transient attributes, and callbacks.
- Faker or FFaker generator names and uniqueness behavior.
- Active Job helpers, Turbo Stream response assertions, and request spec conventions.

Keep examples deterministic. Use fake data for plausible defaults, not for asserted values; values under assertion should be literal and meaningful in the spec.

## Guardrails

- Do not use generic React, Next.js, or API-framework examples for this Rails app.
- Do not let Context7 override local truth from `Gemfile.lock`, app code, or repo-specific skills.
- Do not add a dependency because Context7 documents it; dependency changes need product or implementation justification.
- Do not paste large documentation blocks into the user response. Summarize the relevant rule and cite the source ID when useful.
- Do not use stale version-specific Rails guides when a Rails 8.1 API source or repo-local behavior answers the question better.
