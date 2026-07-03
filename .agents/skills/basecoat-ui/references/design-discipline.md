# Design Discipline

Use this reference before building or polishing Rails UI with Basecoat. It adapts the strongest anti-generic design rules from `design-taste-frontend` to server-rendered Rails, Turbo, Stimulus, ERB, and Basecoat.

## Design Read

Before writing user-facing UI, state one concise read:

```text
Reading this as: <surface> for <user>, with <density>, <motion>, and <Basecoat style direction>.
```

Examples:

```text
Reading this as: recipe search for a hungry home cook, with dense scan-first results, low motion, and a clean Basecoat utility style.
```

```text
Reading this as: onboarding pantry setup for a returning cook, with calm guided forms, minimal motion, and a warm but not decorative Basecoat theme.
```

Ask one focused question only if the design read forks into meaningfully different products. Do not ask for generic preferences that can be inferred from the app, route, audience, and task.

## Rails Product UI Defaults

Default to practical product UI, not landing-page theater:

- Use Rails-rendered HTML, Basecoat components, Turbo Frames/Streams for server updates, and Stimulus for small behavior not covered by Basecoat.
- Keep product screens dense enough for repeated use. Recipe search, pantry management, saved recipes, and meal planning are tools.
- Prefer native controls and accessible form semantics over custom JavaScript controls unless the interaction earns the complexity.
- Use Basecoat cards for repeated items such as recipe results, saved recipes, meal-plan entries, or search suggestions. Do not nest page sections inside cards.
- Make the primary job obvious in the first viewport. For PennyLunch, that usually means entering ingredients, seeing matches, or resolving missing ingredients.

## Dials

Set these mentally for each surface:

- `BRAND_EXPRESSIVENESS`: 1-10. Product defaults to 3-5. Landing pages can go higher.
- `MOTION_INTENSITY`: 1-10. Rails product defaults to 1-3. Use 4-5 for meaningful state transitions. Avoid 6+ unless the user asks for a marketing or showcase surface.
- `VISUAL_DENSITY`: 1-10. Product defaults to 6-8. Marketing defaults to 3-5.

For high-density screens, use borders, spacing, grouping, and typography before adding more cards. For low-density marketing sections, use real imagery or product context instead of decorative gradients.

## Anti-Default Rules

Avoid these unless the brief explicitly requires them:

- AI-purple gradients, neon glows, generic dark mesh backgrounds, and centered hero sections for app screens.
- Three identical feature cards as the default layout.
- Decorative section-number eyebrows, version stamps, weather/location strips, scroll cues, ornamental status dots, and fake build metadata.
- Fake-precise numbers such as `92% match` unless real data or clearly mocked sample data supports them.
- Placeholder-as-label in forms.
- Repeated `border-t` plus `border-b` on every row of long lists.
- Generic names such as "John Doe", "Acme", "SmartFlow", or invented testimonials in production-facing UI.
- User-facing copy that leaks implementation details such as Rails, Turbo, Stimulus, Basecoat, SDK, or MCP unless the product surface is for developers.
- Em dash characters in visible UI copy. Use a comma, period, colon, parentheses, line break, or regular hyphen.

## Layout Rules

- Mobile collapse must be explicit for every multi-column layout.
- Navigation should stay one line on desktop and stay below 80px tall.
- Use CSS Grid instead of fragile flex percentage math.
- Use `min-h-[100dvh]` for viewport-height sections, not `h-screen`.
- Give fixed-format UI stable dimensions: recipe cards, ingredient chips, result counters, icon buttons, and loading skeletons should not resize when content changes.
- Long recipe names, long ingredient names, errors, and empty states must fit without overlap at mobile and desktop widths.
- Use one corner-radius system per surface. If buttons, cards, inputs, and chips have different radii, the rule must be intentional and consistent.

## State Completeness

Rails/Turbo UI must include the full interaction cycle:

- Loading: skeletons shaped like the final content, especially for recipe result cards.
- Empty: clear next action, not generic encouragement.
- Error: inline for forms, contextual for failed searches, toast only for transient feedback.
- Disabled: preserve label readability and focus behavior.
- Success: update the relevant Turbo Frame or visible state instead of relying only on a toast.

For Turbo Frames and Streams, verify the replacement state and the restored browser history state. A component that works on first load but fails after Turbo navigation is not done.

## Motion

Use motion to communicate hierarchy, feedback, or state change. Do not add animation only to make the screen feel designed.

Rails-friendly defaults:

- Prefer CSS transitions for hover, active, disclosure, and small state changes.
- Prefer Stimulus for tiny behavior that needs state.
- Use only `transform` and `opacity` for animation.
- Gate non-trivial animation with `@media (prefers-reduced-motion: no-preference)`.
- Avoid scroll-hijack, parallax, custom cursors, and pointer physics in product UI.
- Do not attach raw scroll listeners for visual effects. Use CSS scroll-driven animation or IntersectionObserver only when the effect is justified.

## Copy Rules

Re-read every visible string before finishing:

- Prefer concrete verbs: "Add ingredients", "Show recipes", "Save recipe", "Use these first".
- Avoid vague marketing verbs: "Elevate", "Unleash", "Revolutionize", "Seamless".
- Keep CTA intent consistent. Do not use "Find recipes", "Search meals", and "Get matches" for the same action on one screen.
- Keep button labels short enough to stay on one line at desktop.
- Do not invent testimonials, metrics, cuisine claims, nutrition claims, or recipe availability facts.
- Keep recipe and pantry copy practical. Users are trying to decide what to cook.

## Visual Assets

Product UI does not need decorative imagery everywhere, but recipe surfaces should use useful visuals when they help decision-making.

- Use real recipe photos, user-provided assets, generated images, or clearly marked placeholders for recipe imagery.
- Reserve image space to avoid layout shift.
- Do not build fake product screenshots from styled rectangles.
- Do not overlay decorative pills or poetic captions on images.
- If imagery is unavailable, design a strong text-first recipe card with ingredients, time, and match information. Do not pretend the image exists.

## Pre-Flight

Before finishing a Rails/Basecoat UI change, verify:

- Design read matches the implemented surface.
- One Basecoat style pack or one custom Basecoat base style is used.
- One accent system, one radius system, and coherent light/dark tokens are used.
- Buttons, form labels, placeholders, helper text, errors, and focus rings pass contrast.
- No placeholder-as-label.
- Empty, loading, error, disabled, and success states exist where the workflow can reach them.
- Turbo navigation, Turbo Frame replacement, and browser back/forward do not leave stale component state.
- Basecoat interactive components have required JavaScript and keyboard behavior.
- Mobile and desktop screenshots show no overlap or clipped text.
- Visible copy has no implementation leaks, fake data, generic filler, or em dash characters.
- Browser console is clean.
