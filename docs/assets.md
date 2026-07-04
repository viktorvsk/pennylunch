# Brand Assets

PennyLunch uses `public/pen.svg` as the canonical source for browser, install, and in-app brand icons.

The web app install chrome uses the Market Fresh tomato theme color `#dc3f2f` in the HTML metadata, SVG mask icon metadata, and PWA manifest. The generated pen assets do not need to be regenerated when only this theme color changes.

The Market Fresh global ingredient pattern is CSS-only in `app/assets/stylesheets/recipe_theme.css`; it does not introduce a generated asset. The root landing page reuses the same public mascot SVG and PNG icon assets directly.

Generated public assets:

- `icon.svg`, which mirrors the canonical SVG for legacy Rails/default icon URLs.
- `favicon.ico` with 16, 32, and 48 pixel entries.
- `favicon-16x16.png`, `favicon-32x32.png`, and `favicon-48x48.png` for explicit browser favicon links.
- `icon-64x64.png`, `icon-192x192.png`, and `icon-512x512.png` for browser and PWA metadata.
- `icon-maskable-192x192.png` and `icon-maskable-512x512.png` for maskable PWA installs.
- `icon-background-grey-512x512.png` as a muted derivative for alternate low-contrast backgrounds.
- `apple-touch-icon.png` at 180 pixels for iOS home screen installs.
- `icon.png` at 512 pixels for Rails/default compatibility.

When `public/pen.svg` changes, regenerate the PNG and ICO assets with `rsvg-convert` and ImageMagick:

```bash
mkdir -p /tmp/pennylane/icons
for size in 16 32 48 64 180 192 512; do
  rsvg-convert -w "$size" -h "$size" public/pen.svg > "/tmp/pennylane/icons/pen-${size}.png"
done
cp /tmp/pennylane/icons/pen-16.png public/favicon-16x16.png
cp /tmp/pennylane/icons/pen-32.png public/favicon-32x32.png
cp /tmp/pennylane/icons/pen-48.png public/favicon-48x48.png
cp /tmp/pennylane/icons/pen-64.png public/icon-64x64.png
cp /tmp/pennylane/icons/pen-180.png public/apple-touch-icon.png
cp /tmp/pennylane/icons/pen-192.png public/icon-192x192.png
cp /tmp/pennylane/icons/pen-512.png public/icon-512x512.png
cp /tmp/pennylane/icons/pen-512.png public/icon.png
cp public/pen.svg public/icon.svg
rsvg-convert -w 154 -h 154 public/pen.svg > /tmp/pennylane/icons/pen-maskable-154.png
rsvg-convert -w 410 -h 410 public/pen.svg > /tmp/pennylane/icons/pen-maskable-410.png
magick -size 192x192 canvas:'#fff7ed' /tmp/pennylane/icons/pen-maskable-154.png -gravity center -composite -depth 8 PNG32:public/icon-maskable-192x192.png
magick -size 512x512 canvas:'#fff7ed' /tmp/pennylane/icons/pen-maskable-410.png -gravity center -composite -depth 8 PNG32:public/icon-maskable-512x512.png
rsvg-convert -w 512 -h 512 public/pen.svg > /tmp/pennylane/icons/pen-background-source.png
magick /tmp/pennylane/icons/pen-background-source.png -alpha on -fill '#737373' -colorize 100 -channel A -evaluate multiply 0.14 +channel -depth 8 PNG32:public/icon-background-grey-512x512.png
magick public/favicon-16x16.png public/favicon-32x32.png public/favicon-48x48.png public/favicon.ico
```
