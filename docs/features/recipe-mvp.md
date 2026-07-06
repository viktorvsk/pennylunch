# Recipe MVP

PennyLunch stores recipes from the Allrecipes gzip source and lets local users search them by title, category, shortcuts, sorting, and available ingredients.

## Data Source

The default source is:

```text
https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz
```

Override it with the `url` field on the Avo `Import recipes` action.

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

Run the import from `/avo/resources/recipes` with the standalone `Import recipes` action. The action exposes a `url` field for the gzipped recipe JSON source and pre-fills the PennyLunch interview asset URL.

The MVP import intentionally supports only an empty `recipes` table. It downloads the gzip, parses JSON, derives source metadata, and writes rows with PostgreSQL `COPY`. It does not invoke the Python ingredient parser, generate vectors, or create `RecipeIngredient` rows.

The import spec proves source-column fidelity by reconstructing source-shaped JSON from denormalized recipe columns ordered by `source_position` and comparing it to the parsed gzip JSON fixture.

## Ingredient Search

Recipe indexing parses source ingredient lines with the pinned Python `ingredient-parser-nlp` CLI at `libexec/parse_ingredients.py`. The original `ingredients` JSON stays unchanged for source fidelity. Imported recipes have empty derived ingredient fields until indexing runs. Parsed ingredient names are normalized during indexing, stored in the `recipes.ingredient_names` JSONB array, and must never be overwritten with canonical Ingredient names. Parsed names are resolved through the Ingredient catalog only for derived search fields: every `Ingredient` has one canonical `name`, a JSONB array of reviewed normalized `aliases`, and an `optional` flag. Aliases are validated after model normalization so each stored alias maps to exactly one canonical Ingredient name.

Recipe ingredient vectors are generated from non-optional canonical Ingredient names resolved from the parser output. Optional ingredients, such as salt, sugar, water, general cooking oils, cooking spray, vinegar, black pepper, and generic dressing, remain selectable and visible but are excluded from vector text. `RecipeIngredient` rows store the resolved Recipe-to-Ingredient associations used by exact overlap filtering and best-match counts. Unknown parsed recipe ingredient names do not create `RecipeIngredient` rows. `ingredient_parse_data` stores the structured parser output for each source ingredient line, including quantities, units, preparation text, confidence values, and parser flags. Parser name text is normalized during indexing so recipe detail rendering can resolve catalog rows with exact stored-value lookups.

The checked-in manual catalog at `config/ingredient_aliases.yml` is the source of truth for creating Ingredient records. Each entry maps one canonical Ingredient name to normalized parser/source phrases that should resolve to it, for example `avocado` can own aliases such as `avocado`, `avocados`, `ripe avocado`, and `green avocado`. Lookup does not infer plurals; source variants must be explicit aliases. Composite source phrases remain aliases of a canonical name, for example `wheat, rye, and flax hot cereal mix` maps to `cereal mix`.

`BootstrapIngredients` upserts Ingredients from `config/ingredient_aliases.yml`; it does not delete Ingredient rows that are absent from the YAML file. `IndexRecipeJob` runs after import and catalog bootstrap to populate parser data, generate ingredient vectors from non-optional canonical Ingredient names, and recompute `RecipeIngredient` associations from each recipe's normalized `ingredient_names` using the current catalog. Catalog-only changes do not enqueue a separate association rebuild; run `Index selected recipes` for affected or all recipes when `RecipeIngredient` rows must reflect the new catalog. Avo actions enqueue these jobs and handle local resets: `Delete selected recipes` removes recipes and their `RecipeIngredient` rows without deleting Ingredient records, and `Delete selected ingredients` removes Ingredients and their `RecipeIngredient` rows without deleting recipes. Delete recipes first and ingredients second when both local data sets need to be rebuilt.

The default filter strategy is overlap. It treats the Rails array parameter `ingredients[]` as exact canonical Ingredient names selected from the FAB catalog, loads matching non-optional Ingredients by `Ingredient.name`, and keeps every recipe with at least one matching `RecipeIngredient` row. It does not call the Python parser during search requests, and it does not resolve user input through aliases, joined strings, alternate delimiters, or casing changes. If the basket contains only optional or unrecognized ingredients, the ingredient filter is ignored.

Ingredient highlighting is presentation-only. Recipe cards read the enabled visible basket, including optional ingredients, so optional pantry matches such as cooking spray can be highlighted even though they do not constrain the results.

Vector search is enabled only when the Rails cache key `search_strategy` is exactly `vector`. The Avo `Set recipe search strategy` action updates this key directly: the `strategy` value `vector` writes the key without an expiry, while `overlap` writes `overlap`. Any missing or non-`vector` value uses overlap search. Vector search treats user-provided ingredients as canonical Ingredient names, drops optional ingredients, embeds the remaining names, and keeps every recipe whose `ingredients_vector` is within `INGREDIENTS_MAX_COSINE_DISTANCE`. It does not order or limit the candidate relation and does not require an exact canonical ingredient-name overlap once vectors exist.

The default sort is `best_match`. It works with either ingredient filter strategy by counting non-optional `RecipeIngredient` rows, then ordering by fewest missing required catalog ingredients, most matched non-optional basket ingredients, and fewest total required catalog ingredients before the stable rating/time fallback. Optional catalog ingredients and unknown parsed recipe ingredient names are ignored for missing counts. Users can still choose explicit time or rating sorting, which overrides match ordering.

## UI

Routes:

- `/`: static landing page for the product.
- `/recipes`: recipe index.
- `/recipes/:category-slug`: recipe index filtered to a category.
- `/recipes/:friendly-slug-:id`: recipe detail. The trailing numeric id identifies the recipe; the preceding slug is derived from recipe attributes for readability and is not stored.
- `/avo`: local admin for recipe and Ingredient actions.

The index top bar supports:

- title full-text search from the top bar.
- lowercase-normalized category selection through a Basecoat combobox with autocomplete and original source labels.
- icon switch filters for quick recipes where prep plus cook time is less than 30 minutes.
- icon switch filters for popular recipes where rating is greater than 4.8.
- icon dropdown sorting by best matching, total time, or rating.
- a bottom-right ingredients FAB that opens a compact ingredients panel.

The top bar stays sticky at the top while browsing. Top-bar filters auto-apply on change through Turbo navigation, normal filter links are handled by Turbo Drive, and Turbo visits dim the recipe content and ingredients FAB to 30% opacity while showing a large centered spinner in the content area below the top bar. The brand link uses the pen mark from the generated web icon set with `PennyLunch` text and returns to `/`. The admin gear links to `/avo` but opts out of Turbo prefetching so HTTP Basic Auth is requested only during intentional admin navigation. Client-side recipe UI behavior is loaded through Rails importmap and Stimulus controllers. Ingredient-panel filter updates target only the results Turbo Frame; those requests render the frame without the toolbar or permanent FAB shell. Icon controls use Basecoat tooltips that describe the action and current value, and the top-bar search field prompts users to search recipes. Category filter URLs use `/recipes/:category-slug` instead of `?category=...`; direct query-category URLs still render the filtered index without redirecting. Route constraints send `/recipes/:friendly-slug-:id` paths to recipe detail pages and plain slug paths to category indexes. When a category is selected, the index shows a category header above the result grid.

Ingredient search is controlled from an icon-only basket FAB that opens a floating ingredients panel instead of taking top-bar space. The panel stretches from the bottom-right viewport area up toward the sticky top bar. The topbar form keeps one hidden `ingredients[]` input per active ingredient as the server contract.

The panel gets autocomplete options from canonical `Ingredient.name` values plus optional metadata. Users add ingredients from a bottom autocomplete input by choosing a dropdown match or pressing Enter on the active match. Only listed options can be added, exact and prefix matches rank before substring matches, and already-selected names are removed from the suggestions. The selected-ingredients surface keeps the color pen mark centered as a persistent background; when the Market basket is empty, it also shows the empty-state phrase below the mark. Selected ingredients render as a removable row list with required ingredients first and optional ingredients after them. Optional ingredients render as visibly secondary and are saved in the basket, but they are omitted from the hidden filter inputs and never affect ingredient search. `Catalog` emits the short-lived cached recipe catalog containing ingredient options, category labels, and category slugs; Stimulus modules read that catalog from the application layout for FAB autocomplete and category URL construction. The panel stores selected names and enabled state in the `pennylunch.ingredients` cookie so Rails can apply the basket during the first index render when the URL has no explicit `ingredients` parameter. Existing `localStorage` baskets are migrated to the cookie on the next client load. Panel visibility remains transient: outside clicks, normal Turbo navigation, and page refreshes close it. Ingredient-panel filter submissions target the `recipe-results-frame` Turbo Frame, and the FAB is marked `data-turbo-permanent`, so result updates do not replace or close the FAB. On full Turbo navigation, the preserved FAB refreshes against the new toolbar form so the On state and hidden `ingredients[]` inputs stay aligned without issuing a catch-up filter submit. The switch can be on or off independently of whether any ingredients are selected, disabled selections remain saved but are omitted from filter URLs, and enabled non-empty non-optional selections are written to the hidden inputs and included in Turbo filter navigation. The enable control and active FAB state use the herb theme. The shared FAB is rendered from the application layout.

The bottom ingredient input includes a joined photo scan button with AI sparkles and camera icons. It opens a native modal with a large drag-and-drop photo target plus a direct image URL field; choosing or dropping a JPEG, PNG, WebP, or GIF photo starts reading immediately, and pasting a URL starts reading without a separate submit button. While reading, the modal swaps to a quiet AI-thinking spinner with subtle star motion. The server endpoint `POST /ingredient_image` passes either source to `ImageReader`, which prepares a validated SSRF-safe image reference and calls OpenRouter's `google/gemini-2.5-flash-lite` model with `google/gemini-2.5-flash` as a fallback and a forced function call constrained by the current canonical `Ingredient.name` prompt. The JSON response returns only catalog names that were recognized from the image, and the Stimulus FAB controller merges them into the basket cookie and visible row list. If the basket switch is already On, the existing Turbo filter submission path updates results; if it is Off, the detected ingredients are saved but not applied to filtering until the user turns the switch On.

Recipe cards show the image flush to the top edge, title, a clickable category subheader, a short ingredient-name summary, a light rating widget with Basecoat tooltip, and a footer with author, human-readable known total time, and a right-aligned basket readiness percentage. The readiness percentage compares active selected ingredients with resolved non-optional catalog ingredients, stays on the same footer line as the other metadata, and explains the match count in a wrapping Basecoat tooltip that does not clip the pantry-staple note. The time footer item uses a Basecoat tooltip for prep and cook breakdown. Recipe images reserve their layout space, show a subtle branded pen-mark placeholder with a quiet vertical sweep while third-party photos load, and use a small CSS-only zoom on hover/focus. Catalog-resolved ingredient matches from the active index filter are moved to the front of each card summary before the visible summary cutoff and receive a subtle herb highlight. Outside the index filter form, such as on recipe detail pages, matching falls back to the saved enabled basket.

The recipe UI is composed from focused Rails partials for the toolbar, filter controls, result states, cards, show detail panel, shared metadata, and ingredients FAB. A local `recipe_theme.css` layer maps Basecoat variables to the Market Fresh visual system: bright porcelain-neutral surfaces, tomato primary actions and category state, lemon rating and quick-filter state, herb ingredient matches, French-blue reference links, crisp blue-black ink, and a low-contrast ingredient-pattern background. The default product UI stays light and bright instead of following automatic dark color-scheme preferences. `RecipesController` owns request params, cookies, pagination, and next-page URLs; recipe filtering, ingredient filtering, sorting, title search, and similar recipes live under `app/queries`; view-model objects under `app/view_models` own toolbar display state, parsed ingredient display state, and shared recipe catalog payloads; and import COPY stays inside the import service that owns the workflow.

The index uses infinite scroll. The server still accepts `page` internally, but the UI does not show result totals or pagination links. A Stimulus-owned spinner sentinel fetches the next page of cards and appends them to the existing grid.

When no recipes match, the empty state says that no recipe matches yet, suggests reducing filters or removing an ingredient, and links to a random category when categories exist. It does not expose import actions in the user-facing UI.

The show page uses the same sticky top bar surface as the index, but only shows the `PennyLunch` root link and admin gear. The recipe title is the primary `h1` above a joined two-column detail panel: an image/meta column on the left and a same-height structured ingredient list on the right. The ingredient list scrolls inside its column when needed, uses parser data for size, unit, name, and state when present, and ingredient names render as distinct reference links. When one source ingredient line parses to multiple names, the show row keeps those names together and renders each parsed name as its own reference link with the shared row match metadata. Ingredient rows resolve all structured parser names through Ingredient aliases, then render non-optional or unknown rows under `Main ingredients` and optional rows under `Pantry staples`. Ingredient rows already present in the saved basket show a checked marker at the row start instead of highlighting the ingredient link, and clicking that marker removes the matched catalog ingredient from the basket. Catalog-resolved rows that are not in the saved basket show a small `I have it` button at the right; clicking it adds the primary canonical ingredient to the basket cookie, refreshes the row marker, and keeps the basket filter switch state unchanged. The page ends with up to three similar recipes selected by nearest `ingredients_vector` distance, excluding the current recipe and recipes without ingredient vectors.

Recipes whose imported prep plus cook time is `0` are treated as unknown time in the UI. The raw source values stay stored for import verification, but the time badge is hidden and time sorting treats those recipes as the longest.

## Ingredient Admin

Avo is mounted at `/avo` and uses HTTP Basic Auth credentials from `AVO_USERNAME` and `AVO_PASSWORD`. It manages the Ingredient catalog, local recipe reset actions, recipe import, recipe indexing, catalog bootstrap, and search-strategy selection. Ingredients have a required unique canonical `name`, an `optional` boolean, and `aliases` stored as a `jsonb` array. Name and alias values are normalized on model writes; alias validation prevents the same stored alias from mapping to multiple ingredients and prevents aliases from colliding with another ingredient name. The Avo Ingredient resource exposes `name` as text, `optional` as a boolean, and `aliases` as tags so aliases can be edited as a list instead of raw JSON. Repository-owned bulk changes should be made in `config/ingredient_aliases.yml` and applied through `Bootstrap ingredients`; delete Ingredients in Avo first when a clean catalog reload is needed. The Avo Recipe resource is intentionally narrow: it exposes imported recipe records for selection, queued admin actions, and destructive reset actions without making recipe editing part of the MVP workflow.
