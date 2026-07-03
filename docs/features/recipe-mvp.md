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

The first strategy is `naive_vector_search`, configured by `INGREDIENTS_FILTER_STRATEGY`. It parses the user-provided ingredients into ingredient names, embeds those names, selects the nearest top-N recipe candidates within `INGREDIENTS_MAX_COSINE_DISTANCE`, and then applies the selected time or rating sort to that candidate set.

## UI

Routes:

- `/` and `/recipes`: recipe index.
- `/recipes/:category-slug`: recipe index filtered to a category.
- `/recipes/:slug`: recipe detail.
- `/maintenance_tasks`: local task runner.

The index top bar supports:

- title full-text search from the top bar.
- lowercase-normalized category selection through a Basecoat combobox with autocomplete and original source labels.
- icon switch filters for quick recipes where prep plus cook time is less than 30 minutes.
- icon switch filters for popular recipes where rating is greater than 4.8.
- icon dropdown sorting by total time or rating in either direction.
- a bottom-right ingredients FAB that opens a compact ingredients panel.

The top bar stays sticky at the top while browsing. Top-bar filters auto-apply on change through Turbo navigation, normal filter links are handled by Turbo Drive, and the toolbar shows a small spinner during Turbo visits. Ingredient-panel filter updates target only the results Turbo Frame; those requests render the frame without the toolbar or permanent FAB shell. Icon controls use Basecoat tooltips that describe the action and current value. Category filter URLs use `/recipes/:category-slug` instead of `?category=...`; legacy query-category URLs redirect to the slug path. When a category is selected, the index shows a category header above the result grid.

Ingredient search is controlled from an icon-only basket FAB that opens a floating ingredients panel instead of taking top-bar space. The panel stretches from the bottom-right viewport area up toward the sticky top bar. The topbar form keeps a hidden `ingredients` field as the server contract.

The panel gets autocomplete options from `Recipe.ingredient_filter_options`, which is built from `Recipe.pluck(:ingredient_names).flatten` plus safe single-word ingredient terms derived from those known names. Users add ingredients through a one-line autocomplete input. Only listed options can be added, exact and prefix matches rank before substring matches, and already-selected names are removed from the suggestions. Selected ingredients render as removable chips. The panel stores selected names and enabled state in `localStorage`, while panel visibility remains transient: outside clicks, normal Turbo navigation, and page refreshes close it. Ingredient-panel filter submissions target the `recipe-results-frame` Turbo Frame, and the FAB is marked `data-turbo-permanent`, so result updates do not replace or close the FAB. The switch can be on or off independently of whether any ingredients are selected, disabled selections remain saved but are omitted from filter URLs, and enabled non-empty selections are written to the hidden field and included in Turbo filter navigation. The enable control and active FAB state are green. The shared FAB is rendered from the application layout on recipe index and show pages.

Recipe cards show the image flush to the top edge, title, a clickable category subheader, a short ingredient-name summary, a light rating widget with Basecoat tooltip, and a footer with author and known total time. The time footer item uses a Basecoat tooltip for prep and cook breakdown. Recipe images use a small CSS-only zoom on hover/focus. Exact ingredient-name matches from the saved basket are moved to the front of each card summary before the visible summary cutoff and receive a subtle highlight.

The index uses infinite scroll. The server still accepts `page` internally, but the UI does not show result totals or pagination links. A spinner sentinel fetches the next page of cards and appends them to the existing grid.

When no recipes match, the empty state shows a sad face icon, explains that nothing was found, and links to a random category when categories exist. It does not expose import actions in the user-facing UI.

The show page uses the same sticky top bar surface as the index, but only shows the `PennyLunch` root link and maintenance gear. The recipe title is the primary `h1` above a joined two-column detail panel: an image/meta column on the left and a same-height structured ingredient list on the right. The ingredient list scrolls inside its column when needed, uses parser data for size, unit, name, and state when present, and ingredient names render as distinct reference links. Exact ingredient-name matches from the saved basket receive the same subtle highlight. The page ends with three random similar recipes from the same category as a placeholder recommendation block.

Recipes whose imported prep plus cook time is `0` are treated as unknown time in the UI. The raw source values stay stored for import verification, but the time badge is hidden and time sorting treats those recipes as the longest.
