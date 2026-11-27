# SmartSave UI v3 Phase B review

The experimental branch extends the approved three-screen design through the remaining app routes. The charcoal palette and the Phase A captures are available in the [Phase A review](../README.md).

## Representative Flutter captures

Flutter rendered these secondary screens at 430 × 920 logical pixels with simulated phone safe areas, exported at 2×. Both themes use the same disposable SQLite fixture and a local account stub. The amounts and quote examples are illustrative.

| Screen | Light | Dark |
| --- | --- | --- |
| Welcome | [Light](light-welcome.png) | [Dark](dark-welcome.png) |
| Registration | [Light](light-sign-up.png) | [Dark](dark-sign-up.png) |
| Goal progress | [Light](light-goal.png) | [Dark](dark-goal.png) |
| Deposit calculator | [Light](light-deposit-calculator.png) | [Dark](dark-deposit-calculator.png) |
| Transactions | [Light](light-transactions.png) | [Dark](dark-transactions.png) |
| Stock catalogue | [Light](light-stocks.png) | [Dark](dark-stocks.png) |
| Local financial assistant | [Light](light-local-assistant.png) | [Dark](dark-local-assistant.png) |
| Privacy and data | [Light](light-privacy.png) | [Dark](dark-privacy.png) |

## Screen inventory

- Entry and setup · welcome, sign-up, sign-in, password reset feedback, verification, onboarding, demo card connection and failure, risk questions and results.
- Savings and budgeting · savings goals, goal details and editing, contribution sheet, savings plan, deposit catalogue and detail, deposit calculator, comparison and rationale, goal linking, transaction list and detail, transaction editor, balance detail, category spending, monthly budget and spending analytics.
- Investing · stock catalogue and details, beginner education, thesis list and editor, condition editor and assessment history, liquidity, economic scenarios and holdings, alternative Invest entry, bonds and auto-invest.
- Assistance · local assistant and suggestion controls, spending advice, auto-save and recommendations, deposit-filter empty state, floating assistant entry. The existing Phase A Chat continues to provide history, mode controls, prompt suggestions, offline and error handling.
- Account · My Account, profile and edit form, language and appearance preferences, connected accounts, notifications, advice history, privacy, export, synchronization status, legacy recovery, deletion confirmation, subscription and support. Sign-out still uses the existing account action.

## Components

- `EditorialHeader` separates the title and action row, with clipped translucent capsules for contextual actions and back navigation.
- `RecordGroup` uses quiet borderless surfaces for related records. Transaction rows share a grouped surface with dividers. Account settings share a group with individual actions.
- `FinancialFigure` gives amounts and percentages tabular numerals and room to scale on compact screens.
- `EditorSheet` and `showEditorSheet` provide scrollable, keyboard-aware sheets for goal contributions, budgets, export and legacy recovery.
- The existing `GlassSurface` powers the approved dock, contextual controls and the local assistant composer. Effects use Flutter rendering.

## Run with Android Studio

1. Check out `experimental/ui-v3-liquid-glass` and open the repository root in Android Studio with the Flutter and Dart plugins enabled.
2. Point Android Studio at Flutter **3.41.7** with Dart **3.11.5**. Use **JDK 17** for Gradle and install Android SDK Platform **36**, Platform Tools, and an Android emulator through SDK Manager.
3. Use an isolated Firebase project and disposable account with fictional data. Follow the repository’s Firebase setup instructions for local project configuration. Keep those files and credentials out of the commit. [Repository setup](../../../README.md)
4. Run `flutter pub get` from the project root. Start the emulator in Device Manager, select it in Android Studio, and run `lib/main.dart` with a Flutter run configuration.
5. Review **My Account → Profile → Appearance** and **Language**. For online AI against an authorized test proxy, provide `--dart-define=SMARTSAVE_BACKEND_URL=https://<test-proxy>` as an additional run argument.

The image review is limited to the screens listed above. Device-level safe areas, keyboard behavior, optical rendering and live services require an isolated device session.

## Automated verification

Local Flutter analysis reported zero diagnostics. All 66 Flutter tests passed with coverage enabled. The suite includes compact account journeys in both themes, persisted locale and appearance settings, mocked AI streaming and conversation persistence, and a sheet test at 320 × 640 with 1.8× text and simulated keyboard insets. This Linux workspace has no Android SDK or Xcode. The experimental branch uses the existing GitHub Actions workflow for native builds.
