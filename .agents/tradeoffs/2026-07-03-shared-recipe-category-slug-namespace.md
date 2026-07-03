# Shared Recipe And Category Slug Namespace

## Context

Recipe show pages use `/recipes/:slug`. Category filter pages now also use `/recipes/:category-slug` so category selection can be represented as path state instead of `?category=...`.

## Decision

Keep both concepts in the same `/recipes/:slug` namespace for the local MVP. The controller treats a segment that matches a known category slug as a category index page; otherwise it resolves the segment as a recipe show slug.

## Rejected Alternatives

- Move recipe show pages under `/recipe/:slug`: rejected because the MVP already exposes recipe show URLs under `/recipes/:slug`.
- Move category pages under `/recipes/category/:slug`: rejected because the requested product URL was `/recipes/:category-slug`.
- Add a category table now: rejected because the current source remains denormalized and category metadata is not otherwise needed.

## Impact

Category slugs and recipe slugs share one path namespace. In practice, generated recipe slugs include title, category, author, and minutes, while category slugs are short normalized category names, so collisions are unlikely. If a collision does occur, the category page wins.

## Verification

Request specs cover category slug filtering, query-category canonicalization, and recipe show breadcrumbs.

## Retirement Condition

Retire this tradeoff when categories become first-class records, when recipe URLs are allowed to move, or if any imported recipe slug collides with a category slug.
