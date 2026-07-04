---
name: browser-smoke-testing
description: Use for PennyLunch browser verification after Rails, Turbo, Basecoat, CSS, ERB, Stimulus, or navigation changes. Runs the repo-local Playwright smoke workflow, reuses an already-running local app, and avoids starting an extra Rails server unless the user explicitly asks for server lifecycle management.
---

# Browser Smoke Testing

Use this skill for local browser checks in PennyLunch after UI, Turbo, routing, or navigation work.

## Required Workflow

1. Check whether the app is already reachable before any browser automation:

```bash
curl -fsS http://127.0.0.1:3000/up >/dev/null || curl -fsS http://127.0.0.1:3000/recipes >/dev/null
```

2. If the user already has the app running, reuse it. Do not start another Rails server.
3. If the app is running somewhere else, set `PENNYLUNCH_BASE_URL`.
4. Only ask to start a server when no app is reachable and the user has not said one is running.
5. Run the smoke check:

```bash
npm run browser:smoke
```

Use:

```bash
PENNYLUNCH_BASE_URL=http://127.0.0.1:3001 npm run browser:smoke
```

only when the active app is intentionally on a non-default port.

## Dependency Setup

If `node_modules` is missing:

```bash
npm install
```

If Playwright cannot find a browser and system Chrome is unavailable:

```bash
npm run browser:install
```

The smoke script uses `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` when it exists, otherwise it uses Playwright's installed browser. Override with `PLAYWRIGHT_CHROME_EXECUTABLE`.

## Current Smoke Coverage

`script/browser_smoke_show_page.mjs` verifies:

- `/recipes` has recipe cards.
- Clicking the first recipe card navigates to a show page.
- The show page has no breadcrumbs.
- The show page renders a two-column desktop detail layout.
- The image occupies the top of the card and zooms on hover.
- The structured ingredient table has rows.
- The show-page `I have it` ingredient action adds a row ingredient to the saved basket without enabling filters.
- The similar-recipes section renders no more than three recipe cards.
