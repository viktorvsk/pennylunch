---
name: basecoat-ui
description: Use when designing, implementing, integrating, reviewing, or refactoring UI with Basecoat UI/basecoat-css in Rails, Hotwire, Turbo, Stimulus, ERB, plain HTML, or other non-React web stacks. Trigger for anti-generic Rails product UI, Basecoat component markup, Tailwind/Basecoat stylesheet setup, Basecoat JavaScript lifecycle with Turbo or dynamic DOM updates, shadcn-compatible theming, style packs, Rails partial/helper patterns, accessibility checks, and deciding between CDN, npm, or vendored Basecoat assets.
---

# Basecoat UI

## Overview

Use Basecoat as a semantic HTML and Tailwind component layer for server-rendered UI. In this repo, default to Rails 8, ERB, Propshaft, Hotwire, Stimulus, and `tailwindcss-rails` conventions unless local inspection shows the app has moved to an npm or bundler workflow.

Basecoat is version-sensitive. When installing, upgrading, or debugging it, verify the current official docs first. This skill was created against Basecoat v1.0.1 docs on 2026-07-02.

## Workflow

1. Inspect the app before choosing a setup path: read `Gemfile`, layout stylesheet/script tags, `app/assets`, `app/javascript`, Tailwind entrypoints, importmap/package files, and existing view/component patterns.
2. State a one-line design read before building user-facing UI: surface type, user intent, density, motion level, and Basecoat style direction. Ask one focused question only when those choices genuinely diverge.
3. Choose one asset strategy. Prefer local, pinned assets for production Rails work. Use CDN only for throwaway prototypes or when the user explicitly accepts that deployment/CSP/cache tradeoff. Use npm when the app already has a package workflow or when adding one is an intentional project decision.
4. Load Tailwind before Basecoat, load exactly one complete Basecoat style pack, then load project overrides after Basecoat. Do not stack complete style packs.
5. Build views with documented Basecoat root classes, semantic HTML, and `data-*` APIs. Do not copy shadcn React component APIs into Rails views.
6. Add Basecoat JavaScript only for components that need behavior. With Turbo or manual DOM insertion, verify initialization after navigation and dynamic updates.
7. Extract repeated markup into Rails partials/helpers only after at least two real uses expose the right API. Keep helper options close to Basecoat's documented attributes.
8. Verify keyboard behavior, focus rings, dark mode/theme tokens, responsive layout, Turbo navigation, and no console errors before finishing.

## References

- Read `references/rails-integration.md` before adding or changing Basecoat installation, CSS imports, JavaScript imports, Turbo lifecycle hooks, CSP, or Rails partial/helper structure.
- Read `references/design-discipline.md` before building or polishing user-facing screens, redesigns, empty states, recipe search/results UI, dashboards, forms, or marketing surfaces.
- Read `references/component-patterns.md` before creating component-heavy markup, forms, menus, selects, dialogs, tabs, toast, or other interactive UI.
- Read `references/theming-and-quality.md` before choosing a style pack, customizing theme tokens, setting fonts/icons, or doing frontend QA.

## Product Defaults

PennyLunch is a dinner-time recipe finder. UI work should feel like a useful cooking tool: fast search, clear ingredient matching, scannable recipe cards, practical filters, and calm decision support. Avoid marketing-page defaults unless the user asks for a landing page.

Use cards for repeated recipes and saved items, not as nested layout wrappers. Prefer dense but readable forms, ingredient chips, clear empty states, and mobile-first meal-planning flows.

## Source Anchors

Official docs to re-check when facts matter:

- `https://basecoatui.com/introduction/`
- `https://basecoatui.com/installation/`
- `https://basecoatui.com/customization/`
- `https://basecoatui.com/templates/`
- `https://github.com/hunvreus/basecoat`
