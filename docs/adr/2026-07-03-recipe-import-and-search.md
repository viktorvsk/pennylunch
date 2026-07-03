# Recipe Import And Search

Status: accepted
Date: 2026-07-03

## Context

The MVP needs locally testable recipe discovery from a fixed gzipped JSON source. The import must prove that the original fields were stored correctly, and ingredient search must be useful without adding an external vector service.

## Decision

Store recipes in one denormalized `recipes` table with typed source columns plus derived search fields. Import directly into an empty table with PostgreSQL `COPY`. Prove source-column fidelity in specs by reconstructing source-shaped JSON from columns and comparing it with parsed gzip fixture data. Parse source ingredient sentences with a pinned Python `ingredient-parser-nlp` CLI, store the full structured parser output in `ingredient_parse_data`, extract lowercase unique `ingredient_names`, then use those names as the text source for pgvector embeddings. Use PostgreSQL full-text search for titles and pgvector with Neighbor and Informers for ingredient candidate selection, constrained by a configurable cosine-distance threshold.

## Alternatives Considered

- Store raw source JSON and compare it during verification: rejected because it does not prove typed columns were stored correctly.
- Normalize recipes, authors, categories, and ingredients immediately: rejected because the MVP source has no stable external IDs and the first product needs read-only discovery.
- Embed full source ingredient sentences: rejected because quantities, units, and preparation notes dilute matching for pantry ingredients.
- External vector database: rejected because PostgreSQL with pgvector keeps local development self-contained.

## Consequences

The MVP has a simple, inspectable data model and a strong import equality spec. Re-importing changed source data is intentionally not handled yet. Ingredient relevance depends on parser-backed ingredient names and vectors being backfilled through the maintenance UI. Parser output is derived data, so it can be regenerated without changing the original source fields.

## Verification

RSpec covers import equality, duplicate identity rejection, empty-table guard, search filters, sort behavior, and route rendering. `bin/linters/env_access` verifies configuration policy.

## Revisit Condition

Revisit when recipes need repeated imports, source changes, partial refreshes, author pages, or ingredient-level explanations.
