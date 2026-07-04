# Backlog

## MVP Status

- Done: `Recipe` model with denormalized source fields and derived search fields.
- Done: direct empty-table gzip import through Maintenance Tasks.
- Done: import specs reconstruct source-shaped JSON from typed columns.
- Done: recipe index and show pages.
- Done: title, category, quick, popular, ingredient filters.
- Done: time and rating sorting.
- Done: parsed ingredient names stored separately from source ingredient text.
- Done: structured ingredient parser payload stored per source ingredient line.
- Done: local pgvector ingredient candidate search.
- Done: explicit best-match relevance sort.

## Future Work

- Import through a staging table with `ON CONFLICT UPDATE`, and never delete recipes missing from a later source file.
- Filter by author.
- Author page with recipe list, rating distribution, and summary stats.
- Ingredient match explanations and missing-ingredient display.
- Ingredient entry UX outside the compact top bar.
- Ingredient parser confidence review and synonym handling.
- Image caching or proxying for external recipe images.
- Import history and source-file checksum tracking.
