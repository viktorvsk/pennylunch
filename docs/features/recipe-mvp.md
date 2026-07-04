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

Recipe import and vector backfill parse source ingredient lines with the pinned Python `ingredient-parser-nlp` CLI at `libexec/parse_ingredients.py`. The original `ingredients` JSON stays unchanged for source fidelity. Parsed ingredient names are stored as raw parser output in `recipes.ingredient_names` and must never be overwritten with canonical Ingredient names. Parsed names are resolved through the Ingredient catalog only for derived search fields: every `Ingredient` has one canonical `name`, a JSON-array of reviewed raw `aliases`, and an `optional` flag. Aliases are validated to be unique across all ingredients by normalized lookup key so each alias maps to exactly one canonical Ingredient name.

`recipes.ingredients_vector_names` stores only the canonical names that are allowed to affect vector search. Optional ingredients, such as salt, sugar, water, general cooking oils, cooking spray, vinegar, black pepper, and generic dressing, remain selectable and visible but are excluded from `ingredients_vector_names`. `ingredient_parse_data` stores the structured parser output for each source ingredient line, including quantities, units, preparation text, confidence values, and parser flags.

The checked-in manual catalog at `config/ingredient_aliases.yml` is the source of truth for creating Ingredient records. Each entry maps one canonical Ingredient name to raw parser/source phrases that should resolve to it, for example `avocado` can own aliases such as `avocado`, `avocados`, `ripe avocado`, and `green avocado`. Composite source phrases remain aliases of a canonical name, for example `wheat, rye, and flax hot cereal mix` maps to `cereal mix`.

Run `Maintenance::WarmEmbeddingModelTask` to download and warm the local Informers model cache. `Maintenance::SyncIngredientsFromAliasCatalogTask` recreates Ingredients from `config/ingredient_aliases.yml`; before writing anything, it compares the catalog aliases with raw parser names already stored on recipes and fails with the unmapped names if the catalog is incomplete. `Maintenance::BootstrapIngredientsFromRecipeNamesTask` is kept as a legacy alias for the same manual catalog sync path. `Maintenance::DeleteRecipesTask` deletes recipes without deleting Ingredient records so local data can be re-imported and re-indexed after catalog changes. `Maintenance::DeleteIngredientsTask` deletes only Ingredients, `Maintenance::DeleteRecipesAndIngredientsTask` drops both local data sets, and `Maintenance::ReloadIngredientsFromAliasCatalogTask` reloads Ingredients directly from the YAML file without recipe coverage checks for Avo/debugging. `Maintenance::RestoreRecipeRawIngredientNamesTask` repairs local rows that were previously canonicalized by restoring `recipes.ingredient_names` from stored parser data without changing vectors. Run `Maintenance::BackfillRecipeIngredientVectorsTask` after import to populate parser data, refresh `ingredients_vector_names`, and generate ingredient vectors in batches from non-optional canonical Ingredient names.

The first strategy is `naive_vector_search`, configured by `INGREDIENTS_FILTER_STRATEGY`. It parses the user-provided ingredients, resolves parsed names and direct basket values through the Ingredient catalog, drops optional ingredients, embeds the remaining canonical names, selects the nearest top-N recipe candidates within `INGREDIENTS_MAX_COSINE_DISTANCE`, and then applies the selected time or rating sort to that candidate set. If the basket contains only optional ingredients, the ingredient filter is ignored.

## UI

Routes:

- `/` and `/recipes`: recipe index.
- `/recipes/:category-slug`: recipe index filtered to a category.
- `/recipes/:slug`: recipe detail.
- `/maintenance_tasks`: local task runner.
- `/avo`: local admin for the Ingredient catalog.

The index top bar supports:

- title full-text search from the top bar.
- lowercase-normalized category selection through a Basecoat combobox with autocomplete and original source labels.
- icon switch filters for quick recipes where prep plus cook time is less than 30 minutes.
- icon switch filters for popular recipes where rating is greater than 4.8.
- icon dropdown sorting by total time or rating in either direction.
- a bottom-right ingredients FAB that opens a compact ingredients panel.

The top bar stays sticky at the top while browsing. Top-bar filters auto-apply on change through Turbo navigation, normal filter links are handled by Turbo Drive, and the toolbar shows a small spinner during Turbo visits. Ingredient-panel filter updates target only the results Turbo Frame; those requests render the frame without the toolbar or permanent FAB shell. Icon controls use Basecoat tooltips that describe the action and current value. Category filter URLs use `/recipes/:category-slug` instead of `?category=...`; legacy query-category URLs redirect to the slug path. When a category is selected, the index shows a category header above the result grid.

Ingredient search is controlled from an icon-only basket FAB that opens a floating ingredients panel instead of taking top-bar space. The panel stretches from the bottom-right viewport area up toward the sticky top bar. The topbar form keeps a hidden `ingredients` field as the server contract.

The panel gets autocomplete options from canonical `Ingredient.name` values plus optional metadata. Users add ingredients through a one-line autocomplete input. Only listed options can be added, exact and prefix matches rank before substring matches, and already-selected names are removed from the suggestions. Selected ingredients render as removable chips. Optional ingredients render at half opacity and are saved in the basket, but they are omitted from the hidden filter field and never affect vector search. The panel stores selected names and enabled state in `localStorage`, while panel visibility remains transient: outside clicks, normal Turbo navigation, and page refreshes close it. Ingredient-panel filter submissions target the `recipe-results-frame` Turbo Frame, and the FAB is marked `data-turbo-permanent`, so result updates do not replace or close the FAB. The switch can be on or off independently of whether any ingredients are selected, disabled selections remain saved but are omitted from filter URLs, and enabled non-empty non-optional selections are written to the hidden field and included in Turbo filter navigation. The enable control and active FAB state are green. The shared FAB is rendered from the application layout on recipe index and show pages.

Recipe cards show the image flush to the top edge, title, a clickable category subheader, a short ingredient-name summary, a light rating widget with Basecoat tooltip, and a footer with author and known total time. The time footer item uses a Basecoat tooltip for prep and cook breakdown. Recipe images use a small CSS-only zoom on hover/focus. Exact ingredient-name matches from the saved basket are moved to the front of each card summary before the visible summary cutoff and receive a subtle highlight.

The recipe UI is composed from focused Rails partials for the toolbar, filter controls, result states, cards, show detail panel, shared metadata, and ingredients FAB. Query-heavy recipe selection, category catalog lookup, similar recipes, ingredient candidate matching, and import COPY operations live under `app/queries`; page-level controller orchestration lives under `app/services/recipes`.

The index uses infinite scroll. The server still accepts `page` internally, but the UI does not show result totals or pagination links. A spinner sentinel fetches the next page of cards and appends them to the existing grid.

When no recipes match, the empty state shows a sad face icon, explains that nothing was found, and links to a random category when categories exist. It does not expose import actions in the user-facing UI.

The show page uses the same sticky top bar surface as the index, but only shows the `PennyLunch` root link and maintenance gear. The recipe title is the primary `h1` above a joined two-column detail panel: an image/meta column on the left and a same-height structured ingredient list on the right. The ingredient list scrolls inside its column when needed, uses parser data for size, unit, name, and state when present, and ingredient names render as distinct reference links. Exact ingredient-name matches from the saved basket receive the same subtle highlight. The page ends with up to three similar recipes selected by nearest `ingredients_vector` distance, excluding the current recipe and recipes without ingredient vectors.

Recipes whose imported prep plus cook time is `0` are treated as unknown time in the UI. The raw source values stay stored for import verification, but the time badge is hidden and time sorting treats those recipes as the longest.

## Ingredient Admin

Avo is mounted at `/avo` and uses the same HTTP Basic Auth credentials as `/maintenance_tasks`. It manages the Ingredient catalog. Ingredients have a required unique canonical `name`, an `optional` boolean, and `aliases` stored as a `jsonb` array. Alias validation prevents the same normalized alias from mapping to multiple ingredients and prevents aliases from colliding with another ingredient name. The Avo resource exposes `name` as text, `optional` as a boolean, and `aliases` as tags so aliases can be edited as a list instead of raw JSON. Repository-owned bulk changes should be made in `config/ingredient_aliases.yml` and applied through `Maintenance::SyncIngredientsFromAliasCatalogTask`.
