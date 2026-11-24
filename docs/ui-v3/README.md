# SmartSave UI v3 — Phase A review

This child branch starts at the UI v2 experiment, commit `ee9ea86f040d5fc1f80177bf20a52df0e3919e37`. The prototype follows the supplied Liquid Glass guidance. The approval gate covers the three screens below.

| Screen | UI v2 comparison | UI v3 light | UI v3 dark |
| --- | --- | --- | --- |
| Dashboard | [Light](../ui-v2/light-dashboard.png), [Dark](../ui-v2/dark-dashboard.png) | [Light](light-dashboard.png) | [Dark](dark-dashboard.png) |
| Investment Intelligence home | [Light](../ui-v2/light-invest.png), [Dark](../ui-v2/dark-invest.png) | [Light](light-invest.png) | [Dark](dark-invest.png) |
| AI chat | UI v2 used a standard toolbar, bordered messages, and a solid composer | [Light](light-ai-chat.png) | [Dark](dark-ai-chat.png) |

Actual Flutter widget captures use a 430 × 920 logical viewport at 2×, Noto Sans and DejaVu fallbacks, an in-memory seeded finance repository, and a saved fictional chat. The offline label reflects the fixture's unavailable provider. Corresponding light and dark views use the same data. The investment movements use the existing illustrative quote values.

## Changes beyond color

- **Dashboard** — A large financial title and tapered balance hierarchy replace the shortcut-first composition. One grouped savings surface and recent activity sit ahead of research shortcuts. The six equal tiles become a compact route list with existing actions intact.
- **Investment Intelligence home** — Oversized type establishes the research destination. Sample quotes appear as typographic rows with signed values and magnitude marks, ahead of grouped entry points. Each research shortcut opens its corresponding existing analysis tab.
- **AI chat** — A larger title and concise status sit beside history and feature controls. Rounded, asymmetric message shapes give each role a distinct silhouette. An inset contextual notice and a translucent composer separate chat and controls. The history drawer uses a softer edge and a dedicated heading. Existing conversation storage, navigation, streaming, and key handlers remain in place.
- **Navigation** — `AppNavigationBar` now renders a clipped floating capsule with a moving selection highlight and semantic destination labels. The two scrollable prototypes paint beneath the dock and reserve sufficient trailing space to scroll their last content clear. The dock hides while the AI keyboard is open.

## Rendering and accessibility

`GlassSurface` uses Flutter's built-in clipped `BackdropFilter` and restrained opacity and highlight treatments, with no new dependency. Glass is limited to the dock and composer. Scrollable financial cards and quote rows carry no blur. High-contrast and accessible-navigation signals make the glass layer solid and skip the filter. Flutter's disable-animations signal removes the selection animation. Native Reduce Transparency mapping and real-device frame profiling remain open.

The visual treatment approximates the supplied design principles in Flutter. Native UIKit/SwiftUI Liquid Glass optics and on-device compositing were outside this prototype. The desktop capture verifies layout, actual rendering, and typography at the fixture size. iPhone safe areas, software keyboard behavior on hardware, and large text across all locales remain for device review.

## Verification

`flutter analyze --no-pub` reported zero diagnostics. `flutter test --no-pub --coverage --reporter expanded` passed all 65 tests, including the compact account journey in both themes, high-contrast glass fallback, locale switching, and mocked streaming and conversation memory. These checks used local fixtures.
