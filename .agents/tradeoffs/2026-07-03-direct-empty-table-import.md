# Direct Empty-Table Import

Date: 2026-07-03

## Context

The MVP needs a reliable first import from one gzip source. Repeated imports and source drift are known future needs but not part of this phase.

## Decision

Import directly into an empty `recipes` table with PostgreSQL `COPY`. If any recipe already exists, the import task fails before writing.

## Rejected Alternatives

- Stage into a temporary table and upsert: kept in backlog for repeated imports.
- Delete and reload: rejected because it would hide source lifecycle semantics.

## Impact

The first import is simple and fast. Re-running import requires a local database reset until staging upsert support is implemented.

## Verification

RSpec covers the empty-table guard, duplicate source identity rejection, successful import, and source-shaped JSON equality from denormalized columns.

## Retirement Condition

Retire this tradeoff when import supports staging-table upsert without deleting missing recipes.
