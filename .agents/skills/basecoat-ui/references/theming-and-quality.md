# Theming And Quality

Use this reference when choosing visual style, customizing tokens, or verifying Basecoat UI work.

## Style Packs

Basecoat ships complete style bundles named `vega`, `nova`, `maia`, `lyra`, `mira`, `luma`, `sera`, and `rhea`.

Choose one style pack based on product tone, then stick to it. Do not import multiple complete style packs. If the product needs a custom visual identity, import `basecoat-css/base` and write a project style file instead.

For PennyLunch, prefer a calm utility-product direction over a decorative recipe blog. The UI should make ingredient matching, recipe confidence, time, and missing items easy to scan.

Before selecting a style pack, state the design read from `design-discipline.md`. A recipe product screen usually needs lower expressiveness and higher density than a marketing page.

## Theme Tokens

Basecoat uses shadcn-compatible CSS variables. Put broad theme changes in a small CSS file imported after Basecoat.

Typical token file:

```css
:root {
  --background: oklch(0.99 0.01 95);
  --foreground: oklch(0.18 0.02 110);
  --primary: oklch(0.42 0.12 145);
  --border: oklch(0.88 0.02 105);
  --ring: oklch(0.52 0.14 145);
}

.dark {
  --background: oklch(0.14 0.02 120);
  --foreground: oklch(0.96 0.01 105);
}
```

Keep token changes cohesive. Avoid changing one component at a time until the system no longer has a clear theme.

## Fonts

Basecoat does not ship font files. Its default tokens prefer Geist Sans and Geist Mono if available, then system fallbacks.

For production Rails work:

- Prefer self-hosted or packaged fonts over remote font links.
- Keep font imports after Tailwind and before or alongside the theme layer as required by the actual asset setup.
- Override `--font-sans`, `--font-heading`, and `--font-mono` only when the app needs a different identity.

## Icons

Basecoat examples use Lucide SVGs, but Basecoat does not require an icon package and does not ship icons.

Rails-friendly options:

- Inline SVG partials when the icon set is small.
- A gem or vendored icon package when the app standardizes on one library.
- JavaScript-rendered icons only if the app already has an appropriate JS package workflow.

Use one icon family per app surface. Do not mix random copied SVG styles.

## Accessibility Checklist

Before finishing Basecoat UI work:

- Tab through every interactive element.
- Verify visible focus rings.
- Test Escape and click-away behavior for menus, drawers, popovers, dialogs, and selects.
- Confirm labels, helper text, and errors are programmatically connected.
- Confirm disabled/loading states do not trap focus.
- Confirm contrast in light and dark themes.
- Confirm interactive controls have stable names for screen readers.

## Visual QA

Check at least one mobile and one desktop viewport for user-facing UI changes. For component-heavy work, use a browser screenshot and inspect:

- No overlapping text or controls.
- Long recipe names, long ingredient names, and empty states fit.
- Cards remain cards for repeated items only; page sections are not nested card stacks.
- Buttons and inputs keep stable height across loading/error states.
- Turbo navigation and back/forward cache do not leave menus or tabs stale.
- Visible UI copy has no em dash characters, fake metrics, generic filler names, or internal implementation details.

## Rails Validation

Use validation proportional to the change:

- View/helper change: run targeted helper/view/system specs if present.
- New interaction: test in browser with Turbo navigation and browser console open.
- CSS/build setup change: run the Rails asset build command used by the repo and boot the app.
- Accessibility-sensitive control: add or update system coverage for the critical path.

Do not finish with unverified Basecoat setup. If a build or browser check cannot be run, say exactly why.
