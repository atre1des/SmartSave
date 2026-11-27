# SmartSave UI v2 experiment

The experiment lives on `experimental/ui-v2`. Its exact base is development commit `f1ed26e266e4ee17f69a7b164b2f2d59f9844d8d`, which includes Stage 8.5 conversation memory. The baseline is the recovery and comparison point. These commands use separate checkout directories and keep the existing app available.

## Run the original UI

```sh
git clone --branch development https://github.com/atre1des/SmartSave.git SmartSave-original
cd SmartSave-original
git switch --detach f1ed26e266e4ee17f69a7b164b2f2d59f9844d8d
flutter pub get --enforce-lockfile
flutter run -d <device-id>
```

## Run the experimental UI

```sh
git clone --branch experimental/ui-v2 https://github.com/atre1des/SmartSave.git SmartSave-ui-v2
cd SmartSave-ui-v2
flutter pub get --enforce-lockfile
flutter run -d <device-id>
```

Use Flutter 3.41.7 with Dart 3.11.5. Set up the usual Android SDK or iOS toolchain and replace `<device-id>` with a connected device or emulator from `flutter devices`. Use a disposable Firebase account with fictional data or an isolated Firebase project. For the latter, put its Android/iOS client configuration in the local checkout and pair any online assistant test with an authorized HTTPS test proxy for that project using `--dart-define=SMARTSAVE_BACKEND_URL=<test-origin>`. Keep test-project changes out of Git. Theme selection is under **My Account → Profile → Appearance** and stays on the device.

## Visual comparison

The captures exercise the actual Flutter Dashboard and Invest shell with identical seeded, fictional local data, stubbed sign-in and no external services. They use a 430 × 920 logical-pixel viewport and Noto Sans and DejaVu Sans fallback fonts loaded for consistent rendering in the Linux test harness. The original capture shows its existing light theme.

| Screen | Original | Experimental light | Experimental dark |
| --- | --- | --- | --- |
| Dashboard | [Original](original-dashboard.png) | [Light](light-dashboard.png) | [Dark](dark-dashboard.png) |
| Invest | [Original](original-invest.png) | [Light](light-invest.png) | [Dark](dark-invest.png) |

The [screen audit and redesign plan](../STAGE_9_DESIGN_PLAN.md) enumerates the routes and shared controls. Captures demonstrate the fixture presentation. Device-specific typography, safe areas, and live integrations require separate review.

## Verification and remaining review

Locked dependency resolution and analysis passed. All 64 Flutter tests passed with coverage, including representative flows in both themes and the Stage 8.5 conversation-memory regressions. The branch push triggers the same Analyze, Test, Android debug, unsigned iOS, and Security Scan checks as the main CI workflow. Native-device interaction and visual review, larger text scales across every route, and full responsive web review remain open. Existing untranslated legacy copy is outside this visual experiment.
