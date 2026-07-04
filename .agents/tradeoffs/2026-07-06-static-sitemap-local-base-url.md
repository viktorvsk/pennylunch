# Static Sitemap Local Base URL

Date: 2026-07-06

## Context

PennyLunch serves `robots.txt` and `sitemap.xml` from `public/`. Static files cannot use the deployment-specific `PENNYLUNCH_BASE_URL`, and the repository does not define a canonical production hostname.

## Decision

Use the checked-in default local base URL, `http://127.0.0.1:3000`, for the static sitemap and robots `Sitemap` directive. List only stable public entry points: `/` and `/recipes`.

## Rejected Alternatives

- Generate sitemap content dynamically from Rails configuration: rejected because the requested artifact is a file under `public/`.
- Guess a production domain: rejected because no canonical host is present in repository configuration or docs.
- Include dynamic recipe and category URLs: rejected because static content would quickly become stale as imported recipe data changes.

## Impact

The files are valid and useful for local/default deployments, but production deployments on a public hostname must replace the sitemap host before relying on search engine indexing.

## Verification

`spec/architecture/seo_assets_spec.rb` parses the sitemap as strict XML and asserts that robots excludes admin, health, and image-reading endpoints.

## Retirement Condition

Retire this tradeoff when PennyLunch has a canonical production host or when sitemap generation moves behind a Rails route that can use configured public URL data.
