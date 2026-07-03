# Ingredient Relevance Ranking

Date: 2026-07-03

## Context

Ingredient search returns semantically relevant candidates. Re-sorting those candidates primarily by time or rating can make irrelevant-looking results appear before better ingredient matches, especially for broad one-word searches such as `avocado`. A pure top-N window can also include irrelevant recipes when only a small number of recipes have vectors, so the candidate window needs a simple distance guard.

## Decision

Use vector search to narrow recipes to top-N ingredient candidates within a configurable maximum cosine distance. Keep ingredient relevance as the primary order, then apply the selected time or rating sort as a secondary ordering.

## Rejected Alternatives

- Sort-first ordering: rejected because it hides better inventory matches behind faster or higher-rated weaker matches.
- No distance threshold: rejected because partially backfilled datasets can return irrelevant recipes inside the top-N window.

## Impact

Users see ingredient-relevant recipes first while still getting predictable secondary ordering. Very relevant recipes outside the top-N candidate set can be omitted, and matches beyond the configured cosine distance are hidden.

## Verification

Search specs prove ingredient relevance stays ahead of rating sort, and request specs prove distant ingredient candidates are excluded from the browser-facing route.

## Retirement Condition

Revisit when the UI adds an explicit relevance sort, match explanations, or enough real usage data to tune the default distance.
