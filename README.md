# SmartSave

SmartSave is a Flutter capstone MVP for understanding everyday spending, planning savings goals, comparing illustrative deposit products, and reviewing sample investment information. The mobile UI is based on the team's [Figma key screens](https://www.figma.com/design/B1IgCz1Vha2ikNryzEtB3j/SmartSave-%E2%80%94-Key-Screens--UI---Copy-?node-id=0-1).

> **This is an educational local demo, not a production finance application.** Authentication is simulated; all seeded account, transaction, deposit-rate, stock and advice records are fictional. No bank is connected, no financial data is imported, and no money or securities can be moved or purchased.

## Project Overview

SmartSave is a personal finance and investment research application built as a capstone project. It provides:

- **Transaction tracking** — Record, categorize, and analyze spending with budgets and month-over-month comparisons
- **Savings goals** — Create goals with targets and deadlines, track progress, and calculate monthly contributions
- **Deposit comparison** — Browse sample bank deposit products with filters and simple-interest calculations
- **Investment Intelligence** — Structure investment theses, define testable conditions, record assessments, analyze liquidity, and simulate economic scenarios
- **AI Assistant** — Local rule-based financial assistant with optional OpenRouter streaming integration

## Technologies

| Layer | Technology | Version |
|-------|------------|---------|
| Framework | Flutter / Dart | ^3.11.5 |
| State Management | Riverpod (ChangeNotifierProvider) | ^2.4.9 |
| Local Database | SQLite (sqflite) | ^2.3.0 |
| Local Preferences | SharedPreferences | ^2.2.2 |
| HTTP Client | Dio | ^5.5.0+1 |
| Markdown Rendering | flutter_markdown | ^0.7.4 |
| SVG Assets | flutter_svg | ^2.3.0 |
| Backend Proxy | Node.js / Express | - |
| AI Provider | OpenRouter (Free-tier only) | - |

## Architecture

```
lib/
├── main.dart                     # App entry, DI setup
├── data/
│   ├── finance_repository.dart   # SQLite schema + ALL CRUD operations
│   ├── finance_controller.dart   # Riverpod ChangeNotifier
│   ├── providers.dart            # Riverpod providers
│   ├── investment_models.dart    # Thesis, Condition, Assessment, Holding models
│   ├── financial_math.dart       # Interest, goal calculations
│   └── investment_analysis.dart  # Liquidity, ripple calculations
├── features/
│   ├── app/                      # Auth, onboarding, AppShell
│   ├── transactions/             # Transaction screens
│   ├── goals/                    # Goals screens
│   ├── invest/                   # Investment screens (Intelligence, Stocks, Bonds, Auto)
│   ├── profile/                  # Profile, settings, privacy screens
│   └── advice/                   # AI assistant screens
├── ai/                           # AI assistant service (OpenRouter + local fallback)
└── shared/                       # Theme, reusable widgets

backend/
├── server.js                     # Express OpenRouter proxy (free-tier only)
├── package.json
└── .env                          # OPENROUTER_API_KEY (gitignored)
```

## Prerequisites

- **Flutter SDK** stable with Dart 3.11 or newer (tested with Flutter 3.41.7 / Dart 3.11.5)
- **Android Studio** with Android SDK/platform tools for Android builds
- **Xcode** on macOS for iOS builds (not available from Windows development environment)
- **Node.js** 18+ for backend proxy server
- **Android emulator/device** or **iOS simulator/device** for interactive testing

## Install and Run

### Flutter App

From the project root:

```bash
flutter pub get
flutter run
```

To list available targets:

```bash
flutter devices
```

To target a specific connected device:

```bash
flutter run -d <device-id>
```

Android APK build:

```bash
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

### Android Setup

1. Install Android Studio and an Android SDK platform/build-tools version supported by the installed Flutter release.
2. Create/start an Android Virtual Device in Android Studio Device Manager, or enable USB debugging on an Android phone and connect it.
3. Accept Android SDK licenses if Flutter requests them, then confirm the target with `flutter devices`.

### iOS Setup

iOS builds require macOS and Xcode. From a Mac with Xcode and CocoaPods configured:

```bash
flutter pub get
open ios/Runner.xcworkspace
# Adjust native signing/capabilities if needed
flutter run
```

### Backend Setup (OpenRouter Proxy)

The AI assistant uses a local Express.js proxy to OpenRouter (free-tier models only):

```bash
cd backend
npm install
# Create .env file with your OpenRouter API key:
# OPENROUTER_API_KEY=sk-or-v1-...
# OPENROUTER_MODEL=baidu/ernie-5.5-flash-preview:free
npm start
```

The proxy runs on `http://localhost:3001` by default. The Flutter app connects to this endpoint for AI streaming responses.

**Important:** The backend enforces free-tier models only (`:free` suffix). Paid models are rejected at startup.

### Firebase Setup Prerequisites

> **Not yet configured** — This is planned for production migration.

For future Firebase integration, the following will be required:

1. **Firebase Project** — Create at [Firebase Console](https://console.firebase.google.com)
2. **Authentication** — Enable Email/Password, Google, and Apple providers
3. **Firestore Database** — Create in Native mode (production)
4. **Configuration Files** — Download and place:
   - `google-services.json` → `android/app/` (Android)
   - `GoogleService-Info.plist` → `ios/Runner/` (iOS)
5. **FlutterFire CLI** — Configure via `flutterfire configure`
6. **Security Rules** — Deploy Firestore rules for per-user data isolation

## Local Data and Demo Behavior

- The database is created on first launch and seeds fictional sample records for the current and prior month. Current-month totals reconcile to the dashboard/category examples; prior-month sample rows drive the comparison screen.
- New transactions, edited records, goals, contributions and budget changes are stored locally and survive normal app restarts on mobile.
- Sign-up and sign-in accept local demo inputs only; they do not verify credentials. **Do not reuse a real password.**
- The card-link flow ends in an explicitly simulated connection failure or manual-entry path. No credentials are requested and no bank service is called.
- Deposit rates and stock quotes are prototype samples. The deposit calculator is a simple-interest estimate, not a bank offer; all relevant screens show source/assumption disclaimers.
- Profile → **Reset demo data** restores the deterministic fictional sample records. Profile → Privacy & data → Delete account clears local demo state and returns to Welcome. Neither action disconnects a real bank account because none is connected.

## Tests and Checks

```bash
flutter analyze
flutter test
```

Verified during this implementation:

- `flutter analyze` — passed with no issues.
- `flutter test --no-pub test/investment_intelligence_test.dart` — 5 tests passed, covering persistence/history, evidence classification, liquidity, scenarios, and saved assumptions.
- `flutter test --no-pub test/finance_repository_test.dart` — 4 existing SQLite regression tests passed.
- `flutter test --no-pub test/widget_test.dart` — 4 existing formatting/arithmetic/widget tests passed.
- `flutter build apk --debug` — succeeded; output: `build/app/outputs/flutter-apk/app-debug.apk`.
- The new investment UI-flow test and the existing onboarding journey test each timed out after 10 minutes in this Windows environment; they are not verified as passing.
- No Android emulator or physical Android/iOS device was attached; live device interaction and iOS execution remain unverified.

## Branching Strategy

This repository follows a standard Git branching model:

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready code. Protected branch. |
| `development` | Integration branch for ongoing development. |
| `feature/*` | Individual feature branches (e.g., `feature/firebase-auth`, `feature/sync-service`). |
| `fix/*` | Bug fix branches. |
| `release/*` | Release preparation branches. |

### Workflow

1. Create feature branch from `development`: `git checkout -b feature/xxx development`
2. Make changes, commit with conventional commit messages
3. Push feature branch and open Pull Request to `development`
4. CI must pass (analyze, test, build)
5. Code review and approval required
6. Merge to `development` via squash merge
7. Release: merge `development` to `main` via PR

### Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`

Examples:
- `feat(auth): add Firebase email/password sign-in`
- `fix(transactions): correct category filter bug`
- `docs(readme): add backend setup instructions`
- `test(repo): add goal contribution tests`

## GitHub Issue Labels

The following labels are configured for issue tracking:

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `security` | Security-related issue |
| `database` | Database/schema related |
| `authentication` | Auth/identity related |
| `synchronization` | Sync/offline related |
| `testing` | Testing infrastructure or coverage |
| `documentation` | Documentation improvements |
| `dependencies` | Dependency updates |
| `performance` | Performance optimization |

## Pull Request Procedures

1. **Title** — Follow conventional commit format
2. **Description** — Include motivation, changes, testing done
3. **CI Checks** — All must pass (analyze, test, build)
4. **Review** — At least one approval required
5. **Merge** — Squash merge to keep history clean
6. **Delete branch** — After merge

## Known Limitations

- **Demo authentication is not secure authentication.** There is no backend, account recovery service, real user identity, or production-grade credential storage.
- **Bank connection/sync, market feeds, investment orders, broker services, subscription billing, push notifications, support chat and downloadable data export are not integrated.**
- **Risk-profile answers and some preferences are illustrative;** recommendations and market values are demo content, not personalized advice.
- **Budget comparisons and projected goal dates are estimates.** Users should verify rates and financial terms with the relevant provider.
- **Inter is the Figma reference typeface;** if it is not installed on the runtime platform, Flutter falls back to the platform font.
- **The present workspace is Windows;** run iOS builds and simulator checks on macOS.
- **No Firebase integration yet** — all data is local-only.
- **No CI/CD pipeline yet** — GitHub Actions workflow to be added.

## Troubleshooting

- If no device appears, start an emulator or connect a device, then re-run `flutter devices`.
- If packages are unresolved, run `flutter pub get` from the project root.
- If Android license acceptance blocks a build, accept the licenses through the Android SDK tooling/Flutter's diagnostic instructions.
- If Windows test runs report a duplicate `sqlite3.dll` native asset, use a fresh checkout/CI workspace and report the Flutter/Dart version with the logs; do not delete source or user data to address this build-cache issue.
- If backend proxy fails to start, check `.env` file exists in `backend/` with valid `OPENROUTER_API_KEY`.
- If AI assistant shows “offline mode”, ensure backend proxy is running on `http://localhost:3001`.
