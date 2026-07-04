# Landing Page

PennyLunch serves a static startup-style landing page from `/`. The page presents PennyLunch as a pantry-aware AI dinner planning product and sends users into the working recipe application with `Find tonight's dinner` links to `/recipes`.

The landing page is rendered by `LandingController#show` without the application layout. It intentionally does not load the recipe Turbo frame catalog, recipe FAB, Basecoat JavaScript, or recipe app Stimulus controllers. The page is self-contained HTML and CSS, uses the existing mascot assets from `public/pen.svg` and `public/icon-*.png`, and does not add a dependency or generated brand asset.

The installable PWA manifest starts at `/recipes` so installed app launches enter the recipe workflow directly, while the public root remains a marketing page.
