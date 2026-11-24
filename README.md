# SmartSave

SmartSave is a Flutter capstone for personal budgeting, savings planning, and beginner investment research. It records user-entered transactions and contributions in integer KZT, compares illustrative deposit products, and helps users document investment theses and assess them against user-entered evidence. The app provides educational information. SmartSave has no bank connection, money movement, trading, or live market feed.

## What is implemented

- Firebase email/password authentication, email verification, and onboarding.
- Transaction tracking, category budgets, and savings goals with contribution history.
- Sample deposit rates, investment theses, evidence assessments, liquidity scenarios, and assessment history.
- An account-scoped assistant with a local financial helper and optional OpenRouter streaming through the Node.js/Express proxy.
- Account-scoped SQLite storage with SQLCipher on supported native targets, Firebase synchronization for supported records, and privacy settings for local JSON export. See the release checklist for device-verification and recovery limitations.

## Setup

Use Flutter **3.41.7** with Dart **3.11.5**, and Node.js **22** for backend and Firebase tooling. Android CI uses JDK **17**. Use an Android SDK and a device or emulator for Android, or macOS with Xcode, CocoaPods, and an iOS device or simulator for iOS. Android and iOS are the mobile validation targets. Full feature parity on web or desktop has not been established.

```sh
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <device-id>
npm --prefix backend ci
```

Use a disposable Firebase project and test account for demonstrations. Materialize the approved project’s mobile configuration in `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`, matching your app identifiers. Enable email/password sign-in and provision Firestore with the reviewed rules in the isolated project through its authorized owner. Builds alone do not verify configured authentication or synchronization.

The assistant proxy defaults to port 3001. It loads `backend/.env` relative to the server file. Run it with `npm --prefix backend start` and pass the device-reachable URL with `--dart-define=SMARTSAVE_BACKEND_URL=<url>` when running the app. Use trusted HTTPS for remote test endpoints. Set `FIREBASE_PROJECT_ID` for the test project and configure Firebase Admin through Application Default Credentials where required. Provide `OPENROUTER_API_KEY` through the backend environment or an untracked local `backend/.env`. Set an allowed free model with `OPENROUTER_MODEL` on the proxy. The Android emulator defaults to `http://10.0.2.2:3001` in debug builds. The **Proxy reachable** label reflects `/health` liveness. To verify live AI, send a prompt from a signed-in disposable account and confirm a streamed reply. Keep service account credentials, private keys, API tokens, exports, and backups out of Git. The app falls back to a labeled local helper when the proxy is unavailable. Keep production account deletion disabled.

## Verification

```sh
flutter analyze --no-pub
flutter test --coverage
node --test backend/test/server.test.mjs
firebase emulators:exec --project demo-smartsave-rules --only firestore 'node --test backend/test/firestore.rules.test.mjs'
firebase emulators:exec --project demo-smartsave-stage6 --only auth,firestore 'node --test backend/test/firebase.lifecycle.integration.mjs'
gitleaks git --config .gitleaks.toml --redact
git diff --check
flutter build apk --debug
flutter build ios --release --no-codesign
```

Use Firebase CLI 15.11.0 and Java 21 for the emulators. The iOS command runs on macOS. Emulator tests exercise Firebase rules and lifecycle; device verification uses the separate integration tests.

- [Final demo guide](docs/FINAL_DEMO_GUIDE.md)
- [Submission and release verification checklist](docs/FINAL_SUBMISSION_CHECKLIST.md)
- [Native test instructions and remaining release blockers](docs/STAGE_6_5_RELEASE_BLOCKERS.md)
