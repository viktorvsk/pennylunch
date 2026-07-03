# Component Patterns

Use this reference when building Basecoat component markup or Rails partials around Basecoat components.

## Core Conventions

- Basecoat is semantic HTML plus classes such as `btn`, `input`, `field`, and `card`.
- Basecoat v1.0 prefers documented `data-variant` and `data-size` attributes over legacy variant classes.
- Keep markup close to official examples. For interactive components, read the component docs before implementing because ARIA attributes, trigger relationships, and wrapper structure matter.
- Do not port shadcn React props. Rails partials/helpers can expose a small API, but they should generate the documented Basecoat HTML.
- Icons are not bundled. Use the project's chosen icon strategy consistently.

## Common Rails Snippets

Button:

```erb
<%= button_tag "Find recipes", class: "btn", type: "submit" %>
<%= link_to "Clear", pantry_path, class: "btn", data: { variant: "outline" } %>
```

Recipe card:

```erb
<article class="card">
  <header>
    <h3><%= recipe.name %></h3>
    <p><%= recipe.ready_in_minutes %> min</p>
  </header>

  <section>
    <p><%= recipe.summary %></p>
  </section>
</article>
```

Field:

```erb
<div class="field">
  <%= form.label :ingredients, "Ingredients at home" %>
  <%= form.text_area :ingredients, class: "textarea", rows: 4 %>
  <p>Add ingredients separated by commas.</p>
</div>
```

Badge/chip:

```erb
<span class="badge" data-variant="secondary"><%= ingredient.name %></span>
```

## Interactive Components

The Basecoat installation docs currently list these components as needing JavaScript:

- Accordion
- Combobox
- Command
- Drawer
- Dropdown Menu
- Popover
- Select
- Sidebar
- Slider
- Tabs
- Toast

Chart uses a separate helper and requires Chart.js separately.

Before adding one of these components:

1. Read that component's official docs page.
2. Add only the required component script/import, unless the all-in-one bundle is already the deliberate app strategy.
3. Test keyboard interaction, focus return, Escape behavior, click-away behavior, and Turbo navigation.
4. For Turbo Stream replacement or manually inserted HTML, call `window.basecoat.initAll()` only if Basecoat did not initialize the new markup automatically.

## Forms

Prefer native Rails forms and semantic controls. Basecoat should style the control; Rails should own validation and submitted field names.

Use native selects unless the experience needs a custom select or combobox. Custom selects add JavaScript lifecycle and accessibility risk; reserve them for search, multi-select, long option lists, or richer display.

For validation:

- Keep server errors visible near the field.
- Use Rails error state data/classes consistently.
- Preserve `aria-describedby` links when adding helper text and errors.
- Do not rely on color alone for invalid states.

## Recipe App Patterns

For PennyLunch, expected component uses:

- Ingredient entry: field, textarea/input group, ingredient badges, clear buttons.
- Recipe search results: repeated cards, match badges, missing-ingredient badges, useful recipe imagery when available, skeletons shaped like final cards while loading.
- Filtering/sorting: native select or Basecoat select, checkbox, radio group, tabs for result modes.
- Empty state: pantry guidance and one primary action.
- Saved recipes or meal plan: table/list on desktop, cards on mobile.

Avoid building a landing page when the task is the product UI. The first screen should help users enter ingredients or inspect matching recipes.

## Turbo Frames

Wrap independently updating regions in Turbo Frames only when the boundary maps to a real user-visible state:

```erb
<%= turbo_frame_tag "recipe_results" do %>
  <% if recipes.any? %>
    <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      <%= render partial: "recipes/card", collection: recipes, as: :recipe %>
    </div>
  <% else %>
    <%= render "recipes/empty_results" %>
  <% end %>
<% end %>
```

Keep frame IDs stable and meaningful. Do not wrap every small component in a frame "just in case"; too many frames make state harder to reason about.

## Partial API Guidance

Good partial API:

```erb
<%= render "ui/button", label: "Save", variant: "secondary", type: "submit" %>
```

Acceptable output:

```erb
<button class="btn" data-variant="secondary" type="submit">Save</button>
```

Bad API:

```erb
<%= render "ui/button", mood: "quiet-save-mode" %>
```

Keep names boring and aligned with Basecoat docs: `variant`, `size`, `disabled`, `type`, `href`, `icon`, `aria_label`.
