# Recipe Import And Search

Status: accepted
Date: 2026-07-03

## Context

The MVP needs locally testable recipe discovery from a fixed gzipped JSON source. The import must prove that the original fields were stored correctly, and ingredient search must be useful without adding an external vector service.

## Decision

Store recipes in one denormalized `recipes` table with typed source columns plus derived search fields. Import directly into an empty table with PostgreSQL `COPY`, leaving parser-derived ingredient fields empty. Prove source-column fidelity in specs by reconstructing source-shaped JSON from columns and comparing it with parsed gzip fixture data. Recipe indexing parses source ingredient sentences with a pinned Python `ingredient-parser-nlp` CLI and stores normalized parsed names in the `ingredient_names` JSONB array plus structured parser output in `ingredient_parse_data`. Resolve parsed recipe names through the Ingredient catalog's unique alias-to-name mapping into indexed `RecipeIngredient` join rows for exact-overlap filtering and best-match sorting, and into non-optional canonical Ingredient names when generating vectors. Use PostgreSQL full-text search for titles. Ingredient filtering defaults to exact overlap candidate filtering and keeps pgvector with Neighbor and Informers available as a configurable alternate strategy, constrained by a configurable cosine-distance threshold. The default recipe sort is best matching, which ranks the filtered relation by least missing required catalog ingredients, then strongest basket match, before selected fallback sort columns.

## Alternatives Considered

- Store raw source JSON and compare it during verification: rejected because it does not prove typed columns were stored correctly.
- Normalize recipes, authors, categories, and ingredients immediately: rejected because the MVP source has no stable external IDs and the first product needs read-only discovery.
- Embed full source ingredient sentences: rejected because quantities, units, and preparation notes dilute matching for pantry ingredients.
- Use parser output directly as canonical ingredient names: rejected because plural forms, preparation adjectives, and parser-specific variants fragment search and highlighting.
- Include optional pantry staples in vectors: rejected because ingredients such as salt and sugar are usually available and can overpower more meaningful recipe matches.
- External vector database: rejected because PostgreSQL with pgvector keeps local development self-contained.

## Consequences

The MVP has a simple, inspectable data model and a strong import equality spec. Re-importing changed source data is intentionally not handled yet. Ingredient relevance depends on the Ingredient catalog, recomputed `RecipeIngredient` rows, and vectors generated through Avo-queued recipe indexing jobs. Parser output, recipe ingredient associations, and vectors are derived data, so they can be regenerated without changing the original source fields or normalized parser ingredient names.

## Verification

RSpec covers import equality, no-parser import behavior, duplicate identity rejection, empty-table guard, search filters, sort behavior, and route rendering. `bin/linters/env_access` verifies configuration policy.

## Revisit Condition

Revisit when recipes need repeated imports, source changes, partial reindexing, author pages, or ingredient-level explanations.
