# Rails Integration

Use this reference when adding or changing Basecoat setup in a Rails app.

## Decision Tree

1. If the app already has `package.json` and a CSS bundler, install `basecoat-css` through that package manager and import Basecoat from the CSS entrypoint.
2. If the app uses Rails, Propshaft, Importmap, and `tailwindcss-rails` without npm, prefer vendored, pinned Basecoat dist assets for production. Put assets in an explicit vendor path, document the Basecoat version in the filename or nearby comment, and keep the update path obvious.
3. Use the jsDelivr CDN only for prototypes or explicitly accepted tradeoffs. Production Rails apps usually need local assets for CSP, repeatable deploys, and offline build confidence.
4. Do not mix CDN CSS with npm/vendored JS unless there is a clear version pin and a reason. CSS and JS should come from the same Basecoat version.

## CSS Order

Basecoat must load after Tailwind or any stylesheet that emits Tailwind base/preflight. Project overrides load after Basecoat.

Bundler-style entrypoint:

```css
@import "tailwindcss";
@import "basecoat-css/vega";
@import "./app.css";
```

Custom style-pack entrypoint:

```css
@import "tailwindcss";
@import "basecoat-css/base";
@import "./styles/pennylunch.css";
```

Rules:

- Import exactly one complete style bundle: `vega`, `nova`, `maia`, `lyra`, `mira`, `luma`, `sera`, or `rhea`.
- Use `basecoat-css/base` when writing a full custom visual style. Do not import a complete style pack first and then override it wholesale.
- Use `basecoat-css/compat` only for migration from pre-1.0 markup. New code should use the documented 1.0 API.

## Rails Asset Notes

Before editing, inspect the real generated Rails structure. Fresh Rails apps vary by generator flags and Rails version.

Common files to check:

- `app/views/layouts/application.html.erb`
- `app/assets/stylesheets/application.css`
- `app/assets/tailwind/application.css`
- `app/assets/builds/*`
- `config/initializers/assets.rb`
- `config/importmap.rb`
- `app/javascript/application.js`
- `package.json`

For Propshaft, prefer explicit asset names and standard Rails helpers over ad hoc public files. Keep vendored files in a location Propshaft fingerprints and serves.

## JavaScript

Most Basecoat components are CSS-only. Add Basecoat JavaScript only for components that need behavior.

Package imports:

```js
import "basecoat-css/basecoat";
import "basecoat-css/dropdown-menu";
import "basecoat-css/select";
```

All-in-one import:

```js
import "basecoat-css/all";
```

Vendored script tags:

```erb
<%= javascript_include_tag "basecoat/basecoat", defer: true, "data-turbo-track": "reload" %>
<%= javascript_include_tag "basecoat/dropdown-menu", defer: true, "data-turbo-track": "reload" %>
```

Use the all-in-one JS bundle only when file size is not meaningful or the page genuinely uses many interactive components.

## Turbo And Dynamic DOM

Basecoat initializes registered components on page load and when new DOM is inserted. For Rails Hotwire work, still verify behavior under Turbo navigation and Turbo Stream replacement.

Useful hooks when reproduction shows restored or manually inserted markup is not initialized:

```js
document.addEventListener("turbo:load", () => {
  window.basecoat?.initAll();
});
```

If Turbo restores DOM that was already initialized and the component state is stale, reinitialize with force after confirming the issue:

```js
document.addEventListener("turbo:render", () => {
  window.basecoat?.initAll({ force: true });
});
```

Force mode destroys existing component instances and resets transient state. Use it intentionally, not as a blanket fix for unknown issues.

## Rails Markup Patterns

Use plain ERB first:

```erb
<button class="btn" data-variant="secondary" type="button">Save</button>
```

Rails helpers are fine when they keep the Basecoat API readable:

```erb
<%= button_tag "Save", class: "btn", data: { variant: "secondary" } %>
```

Extract partials for repeated structures:

```erb
<%= render "recipes/card", recipe: recipe, match_score: recipe.match_score %>
```

Avoid helpers that hide too much Basecoat behavior behind custom names. If a helper maps variants or sizes, keep the names identical to Basecoat's documented `data-variant` and `data-size` values.

## CSP

If CSP is enabled, local vendored assets usually need no external hosts. CDN setup may require `style-src` and `script-src` changes for the CDN host. Do not loosen CSP broadly; add the narrow host and nonce/hash policy required by the chosen setup.
