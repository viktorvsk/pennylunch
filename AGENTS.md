# PennyLunch

You are building an application that has the following user-facing definition:

```
It's dinner time! Create an application that helps users find the most relevant recipes that they can prepare with the ingredients that they have at home.
```

CRITICAL: our goal is a very simplified version which contains limited amount of features, but every feature we commit to must have production-level quality.

# Technical Stack

## Rails monolith
  - Rails 8.1.x
  - solid_cache - for caching, no Redis
  - solid_queue - for async operations, no Sidekiq
  - Turbo 8 - for advanced UI/UX
  - https://basecoatui.com - for styling, see $basecoat-ui skill
  - foreman - to package application processes in development

## Dependencies
  - Postgresql - for persistence, async jobs and caching
  
## Docker compose
  - The main way to run the application is via `docker compose up --build --pull always` in production.
  - For development we use `docker compose up db` + `bin/dev` - to start dependencies in docker and rails on host

# Project context
  - `README.md` is the canonical project summary.
  - Keep `README.md` aligned with product, setup, configuration, and operations changes.

# TDD
  - Start with the narrowest failing test that proves the contract. For bugs, reproduce before patching when practical.
  - Keep the red failure specific: wrong status.
  - Make the smallest fix, rerun the focused test.
  - See $rails-agent-skills for more details

# Agent operating loop
  - Ground first: inspect the repo, load the relevant skill, read nearby code, tests, and README context, and resolve discoverable facts before asking the user.
  - Planning on steroids: before implementation, proactively surface edge cases, business-rule contradictions, rollout hazards, parity gaps, missing requirements, data-shape/API concerns, and unclear success criteria. Ask as many high-impact questions as needed when the answer cannot be discovered locally.
  - Do not ask questions that inspection can answer. Do ask when product intent, accepted tradeoffs, partial parity, migration semantics, or user-visible behavior is ambiguous.
  - When the user asks to implement and ambiguity is low, make a reasonable assumption and proceed; record important assumptions in the final response.

# Engineering rules

## Basic
  - Scout rule: when touching an area, leave nearby code slightly better; fix relevant pre-existing issues instead of using "pre-existing" as an excuse.
  - Perfection default: aim for the best-in-class solution with no known trade-offs; if a trade-off is intentionally accepted, make it explicit and keep README context aligned when it affects product, setup, configuration, or operations.
  - Run `git status --short` first and preserve unrelated user changes.
  - Use `rg` and nearby files as evidence. Keep diffs surgical.

## Project-specific
  - Git is read-only by default: inspect freely, but do not commit, push, checkout, reset, rebase, merge, tag, stash, or mutate git state unless the user explicitly asks.
  - Single-phase default: implement complete refactors in one phase; avoid legacy paths, staged compatibility, fallbacks, and partial migrations unless the user explicitly asks.
  - Actualize relevant README context and skills whenever code reality changes.
  - CRITICAL: Do not add code comments. Keep existing comments. Its ok if comments will be added due to something external like code generation.
  - Add/update `env.example` for new environment variables: there should be **NO** ENV variables calls in the code that are not listed in `env.example`.

## Code Quality
  - Root cause: since we are working on production code, we MUST always diagnose and fix the root cause instead of only treating symptoms.
  - Production quality only: no MVP shortcuts, stubs, partial behavior, TODO followups, or knowingly incomplete flows unless the user explicitly asks.
  - Product-minded work: actively surface edge cases, contradictory requirements, business-logic gaps, and missing requirements; resolve them when safe, otherwise ask the user.
  - Generic solution: user might provide an example of what you have to achieve, always treat those as just additional context and implement generic solution unless user asks otherwise explicitly.
  
## Dependencies
  - Always use the latest stable dependencies.
  - Use $context7 skill when dealing with dependencies.
  
# Agent guidance
  - For temporary scripts use /tmp/pennylane.
  - Feel free to install additional libraries, packages etc if you need them for your work like `uv`, `jq` etc.
  - Use `uvx` to run quick commands.
