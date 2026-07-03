# Recipe MVP

PennyLunch stores recipes from the Allrecipes gzip source and lets local users search them by title, category, shortcuts, sorting, and available ingredients.

## Data Source

The default source is:

```text
https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz
```

Override it with `RECIPES_IMPORT_URL`.

The import source is a gzipped JSON array. Each item must contain exactly these fields:

- `title`
- `cook_time`
- `prep_time`
- `ingredients`
- `ratings`
- `cuisine`
- `category`
- `author`
- `image`

## Import

Run the import from `/maintenance_tasks` with `Maintenance::ImportRecipesTask`.

The MVP import intentionally supports only an empty `recipes` table. It downloads the gzip, parses JSON, derives search fields, and writes rows with PostgreSQL `COPY`.

The import spec proves source-column fidelity by reconstructing source-shaped JSON from denormalized recipe columns ordered by `source_position` and comparing it to the parsed gzip JSON fixture.

## Ingredient Search

Recipe import and vector backfill parse source ingredient lines with the pinned Python `ingredient-parser-nlp` CLI at `libexec/parse_ingredients.py`. The original `ingredients` JSON stays unchanged for source fidelity. `ingredient_names` stores the unique lowercase names used for search, and `ingredient_parse_data` stores the structured parser output for each source ingredient line, including quantities, units, preparation text, confidence values, and parser flags.

Run `Maintenance::WarmEmbeddingModelTask` to download and warm the local Informers model cache. Run `Maintenance::BackfillRecipeIngredientVectorsTask` after import to populate missing parser data and generate ingredient vectors in batches.

The first strategy is `naive_vector_search`, configured by `INGREDIENTS_FILTER_STRATEGY`. It parses the user-provided ingredients into ingredient names, embeds those names, selects the nearest top-N recipe candidates within `INGREDIENTS_MAX_COSINE_DISTANCE`, keeps ingredient relevance as the primary order, and uses the selected time or rating sort as secondary ordering.

## UI

Routes:

- `/` and `/recipes`: recipe index.
- `/recipes/:slug`: recipe detail.
- `/maintenance_tasks`: local task runner.

The index supports:

- title full-text search.
- lowercase-normalized category combobox.
- quick recipes where prep plus cook time is less than 30 minutes.
- popular recipes where rating is greater than 4.8.
- sort by total time or rating in either direction.
- ingredient textarea backed by pgvector search when vectors exist.

The show page displays the recipe image, rating, time, category, author, and ingredients. It also shows breadcrumbs where `Recipes` links to the root page, the category links to the index with that category filter selected, and the title is the current page.

Recipes whose imported prep plus cook time is `0` are treated as unknown time in the UI. The raw source values stay stored for import verification, but the time badge is hidden and time sorting treats those recipes as the longest.
