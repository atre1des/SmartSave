# Stage 10 Phase A · SmartSave browser workspace

Branch `experimental/stage-10-flutter-web`, based on `ac70823071b27b77e4c229dbda2df6fef3c2259b`.

This is the visual and architectural review of the Flutter browser workspace. The desktop rail replaces the bottom dock at 1024 logical pixels. Home pairs balance and grouped records with spending, budget and goals. Invest gives signed illustrative changes a shared scale and separate research space. Chat provides a history column or a compact history sheet, selectable Markdown and a floating multiline composer.

## Rendered previews

These are Chromium captures of the release-mode Flutter Web review build with one fictional fixture. The Safari-sized image uses an iPhone-sized Chromium viewport.

| View | Light | Charcoal dark |
| --- | --- | --- |
| Desktop Home · 1440 × 1000 | [Light](desktop-home-light.png) | [Dark](desktop-home-dark.png) |
| Desktop Invest · 1440 × 1000 | [Light](desktop-invest-light.png) | [Dark](desktop-invest-dark.png) |
| Desktop AI Chat · 1440 × 1000 | [Light](desktop-ai-light.png) | [Dark](desktop-ai-dark.png) |
| Tablet Home · 834 × 1112 | [Tablet](tablet-home.png) | |
| Mobile Home · 390 × 844 | [Safari-sized](mobile-safari-sized-home.png) | |

## Functional scope

| Working in the preview | Fixture or explicitly unavailable |
| --- | --- |
| Responsive navigation, dashboard and chart rendering, keyboard activation, chat history selection, mode switch, prompt prefill, multiline drafts, theme persistence and EN/KK/RU interface switching | Balances, transaction names, goals, sample market data and initial chat transcript are fictional. Drafts stay in memory and are never sent. |
| Browser Fetch adapter tested against a local stream and HTTP test responses | Live Firebase Auth, UID-scoped financial reads/writes, durable conversation history, deposits and research editors, data export and live Render integration await approval and isolated verification. |

The default web build shows an unavailable state. Use the explicit review flag locally:

```sh
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8601 --dart-define=SMARTSAVE_WEB_REVIEW=true
```

For an offline-friendly engine and typography bundle, use Flutter 3.41.7 and build with `flutter build web --no-web-resources-cdn --pwa-strategy=none --dart-define=SMARTSAVE_WEB_REVIEW=true`. Noto Sans is bundled under its SIL Open Font License. Serve the build on loopback for review.

See the [compatibility matrix](../WEB_COMPATIBILITY_AUDIT.md) and [architecture and hosting plan](../WEB_ARCHITECTURE.md). Changes are in the conditional browser entry, review widgets and data contract, shared type-scale options, browser AI transport, web bootstrap metadata, local font assets, and review docs.

## Verification boundaries

Chromium coverage does not establish native Safari, Android Chrome, browser zoom, hardware keyboard or device-level safe-area parity. Auth session isolation in a real browser, live OpenRouter and authorized Render preflight remain Phase B verification. Firestore emulator results exercise the existing rules without using production credentials or records.

## Phase A checks

- Locked dependency resolution, Flutter analysis, standard web build, and the separate isolated review build passed. Flutter analysis reported zero diagnostics.
- The existing Flutter regression suite passed 66 tests with coverage, including mobile navigation, locale, appearance, finance and mocked AI memory and streaming.
- Backend security and AI proxy tests passed 27 checks. The local Firestore emulator passed 9 rule tests, including cross-account denial.
- Chromium checked keyboard activation, preview history and multiline drafting, resize and compact navigation, locale switching, theme persistence, and the default build's unavailable state. A local Fetch test withheld the final SSE event until the browser acknowledged the first Unicode event. It also checked 429 Retry-After and redirect rejection.
