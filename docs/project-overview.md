# SmartSave — Capstone project overview

## Product and problem

SmartSave is a cross-platform fintech learning prototype for people who want a clearer view of everyday spending and practical savings progress. The Figma product direction combines transaction tracking, budgets, goal planning, deposit comparisons, risk-profile context and explanatory recommendations.

The MVP is intentionally local-only. It demonstrates financial calculations and interface flows without connecting to a bank, broker, payment processor or remote service.

## Implemented features

1. **Financial overview, transactions, budgets and analytics** — derived local balance and monthly category totals; searchable/filterable transactions; add/edit/delete; category detail; editable monthly budget; current/prior-month category comparison.
2. **Savings goals and planning** — create/edit/delete goals, target/deadline/purpose, progress and remaining amounts, manual local contributions, monthly plan estimates and selectable spending-cut ideas.
3. **Deposit and investment information** — sample rate catalogue, term/top-up/withdrawal filters, product comparison, simple-interest estimate, rationale and source disclosures; fictional watchlist/detail views and recommendations.
4. **Account, onboarding, risk and settings** — mock auth, multi-step onboarding, simulated connection failure, five-question local risk quiz, profile/settings, privacy, support, advice history, subscription preview, notification preferences and local demo reset/deletion.

All 39 product frames in the Figma file are represented by the implementation or its explicitly labelled demo/Coming later states. The visual audit [figma-audit.md](figma-audit.md) documents which flow steps had to be completed because corresponding frames were not supplied.

## Main user journey

Welcome → local demo sign-up/sign-in → three onboarding pages → optional simulated read-only card setup or skip → five-question risk quiz → illustrative Moderate profile → five-tab dashboard. The user can inspect analytics, change a category budget, add/edit/delete transactions, create a goal, record a contribution, compare sample deposits, inspect stock examples and manage profile/privacy settings. Local changes persist across app restarts on mobile.

## Technology and architecture

- Flutter and Dart; Material 3 controls styled with the observed SmartSave color, spacing and typography conventions.
- Riverpod `ChangeNotifierProvider` shares a small finance controller between screens.
- `FinanceRepository` owns SQLite schema, seed/reset logic and queries; UI screens do not issue SQL.
- SQLite stores records in integer tenge to avoid binary floating-point currency errors. Demo auth/profile flags use SharedPreferences.
- Deposit interest uses simple interest: `principal × nominal rate basis points × months / 120000`, rounded down to the nearest tenge. Goal monthly contribution uses integer ceiling division so the target is reached by the selected deadline.
- Figma logo SVGs and navigation icons are local files under `assets/figma/`; temporary asset URLs are not used at runtime.

## Persistence and fictional demo data

SQLite seeds a deterministic set of fictional transactions for the current and previous month, three goals, category budgets, sample deposit products, advice entries and local preference defaults. Seed data is marked `Sample data` and is reset from Profile → Reset demo data. Contributions, transactions, goals and budgets are local and survive mobile app restarts. The stored opening balance plus all seed transaction flows produce the visible initial balance; later transactions update it through the same aggregate query.

## Testing performed

- `flutter analyze` reported no issues before the last data-driven comparison/watchlist changes; the final rerun was blocked by the environment's command permission check.
- An earlier automated run of repository CRUD/aggregate tests, money formatting/math tests and the primary-button widget test passed (`+8`), before later comparison assertions and the journey test were added.
- Android debug APK build succeeded before the final small comparison/watchlist changes; rebuild the final source in CI.
- An onboarding-to-core-features widget journey test was added but was not successfully rerun after a Windows Flutter native-assets duplicate-file crash. Rerun it in a clean workspace/CI runner.
- No Android emulator or physical device was attached. iOS execution is unavailable on Windows; run iOS verification on macOS/Xcode before submission.

## Known limitations

- Authentication is for demo navigation only, not secure or identity-verified.
- The “connected” card presentation is a fictional/read-only demo state. Connection attempts end in a simulated failure; there is no live import or bank sync.
- Sample rates, stock prices, advice and risk allocation are illustrative. The app does not offer financial advice, live market data, investment orders or money movement.
- Some Figma details are not available as states/flows (onboarding steps 2–3 and quiz questions 1, 3–5); completion screens are locally authored in the same visual language.
- The Figma board specifies Inter, but no font file was supplied. The app requests Inter and uses the platform fallback when unavailable.
- Export, account recovery, support chat, premium billing and scheduled push notifications have no service integration.

## Future improvements

1. Verify every screen on a real Android device and an iOS simulator, then tune responsive behavior and accessibility semantics.
2. Have the team rerun the widget journey and full suite in clean Windows/CI and macOS environments.
3. Obtain approved Inter font files and confirm all imported artwork against the Figma renders.
4. If product/legal scope permits, define a backend and provider before implementing secure authentication or regulated data connectivity.
5. Replace fictional data with a clearly governed source, show freshness/provenance, and add compliance review before any recommendation or investing workflow is treated as real.
