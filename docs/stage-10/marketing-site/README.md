# SmartSave marketing site

This experiment starts from `2cafe0654cc3fabfe904c0673439772b1299f6de`. The Finotive reference informed the two-column hero, floating capsule navigation, italic editorial line, layered phone, compact calls to action, and the stacked mobile composition. SmartSave supplies the palette, copy, logo treatment, and actual Flutter captures. The hero overlays show example values from the same fictional finance fixture.

## Structure and local preview

- `marketing/index.html` contains the landing page and its SEO metadata.
- `marketing/styles.css` contains the responsive layout, focus and motion styles.
- `marketing/menu.js` handles compact navigation disclosure and Escape.
- `marketing/assets/` contains optimized WebP derivatives of approved mobile captures, the generic brand mark, and locally hosted, SIL OFL-licensed Noto font subsets.
- `marketing/build.py` checks local references, alt attributes and heading order and assembles the static release in `marketing/dist/`.

From the repository root, run `python3 marketing/build.py`, then `python3 -m http.server 8620 --bind 127.0.0.1 --directory marketing/dist`. Open `http://127.0.0.1:8620`. There are no JavaScript dependencies to install.

Home, Features, How it works, About, Contact, and Get the app link to sections on the page. Feature cards link to their matching product showcases. Contact links to the existing project repository. Store listings, a dedicated support address, and standalone legal pages were unavailable in the source, so the site uses a coming-soon message and a working showcase CTA.

## Chromium captures

- [Desktop hero · 1440 px](desktop-hero.png)
- [Full desktop](desktop-full.png)
- [Mobile hero · 390 px](mobile-hero.png)
- [Full mobile](mobile-full.png)
- [Tablet · 768 px](tablet.png)
- [Phone and analytics close-up](hero-mockup.png)

## Future Vercel deployment

Only after deployment is authorized, import the repository into Vercel as a new project. Set **Root Directory** to `marketing` and **Framework Preset** to **Other**. Set the **Build Command** to `mkdir -p dist && cp -R index.html styles.css menu.js assets dist/` and the **Output Directory** to `dist`. The site needs no environment variables or install step. Select the reviewed branch as the production branch before deploying, inspect the preview, then attach the authorized domain and use an absolute HTTPS image URL for `og:image`. This experiment has only been served on loopback.

Browser verification used Chromium. Physical-device Safari was outside this pass. Flutter files and configuration are outside this change set, and the Flutter regression suite was not rerun.

## Checks

The static build and JavaScript syntax check passed. Chromium checked the production output at 1440, 1280, 1024, 768, 430, 390, and 360 px. All seven widths passed anchor, image loading, keyboard focus and mobile disclosure checks, with no document overflow, missing resources, or console errors. The diff contains only the isolated marketing directory and this review folder.
