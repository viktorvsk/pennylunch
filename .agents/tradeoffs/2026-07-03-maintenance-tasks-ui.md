# Maintenance Tasks UI

Date: 2026-07-03

## Context

Local users need browser-triggered import, model warmup, and vector backfill without custom task-runner UI.

## Decision

Use Shopify Maintenance Tasks mounted at `/maintenance_tasks` and protect it with HTTP basic authentication.

## Rejected Alternatives

- Rails tasks only: rejected because the MVP goal includes self-service through the browser.
- Custom admin page: rejected because it would duplicate task lifecycle, status, and retry behavior.

## Impact

The app gains a proven task UI quickly, but it exposes a powerful local maintenance surface and adds an engine dependency.

## Verification

Request specs verify basic auth. Task specs verify the local task wrappers call the intended services.

## Retirement Condition

Revisit if PennyLunch gains real users, roles, or a permanent admin surface.
