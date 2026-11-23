# Stage 6 verification

Base commit `334de9fa7f103142ef11b21cd05ecccf73ddec9c` on `development` is the merge of Stage 5 PR #1. Stage 6 uses `stage-6/regression-and-integration` and the existing Flutter 3.41.7, Dart 3.11.5, JDK 17 CI pin, dependency cache and verified SQLite FFI binary. The starting checkout was clean. No production Firebase service was used.

## Verification matrix

| Feature / Requirement | Verification method | Result | Evidence | Remaining limitation |
| --- | --- | --- | --- | --- |
| Locked Flutter dependencies and analyzer | Flutter CLI | PASS | Locked resolution and analysis exited 0, with zero diagnostics | Native dependencies require their platform build |
| Flutter unit and widget regression | `flutter test --coverage` | PASS | 42 passed, exit 0, `coverage/lcov.info` generated | Native integration tests are a separate command |
| Sign-up, verification and navigation | Flutter widget with fake Auth | PASS | Onboarding continues through email verification, quiz, goals and transaction creation | Actual Flutter Firebase session restoration was not exercised |
| Registration, email verification, password reset, login, logout | Auth emulator and Firebase JS SDK | PASS | Lifecycle test creates accounts, applies emulator action codes, rejects the old password and signs in from a fresh client | Production email delivery and native session persistence are unverified |
| Native profile settings, state restoration, error and layout matrix | Manual Flutter/device | NOT TESTED | Existing widget tests only traverse selected screens | Exercise settings and constrained viewports on devices |
| KZT totals, categorization, persistence, budgets and savings | SQLite unit tests and widget tests | PASS | Transactions CRUD/filter, seeded totals, goal contributions, budget conflict checks, savings and integer arithmetic | No broad device UI audit |
| Deposit comparisons and estimates | SQLite and financial unit tests | PASS | Deposit filter and simple-interest assertions | No real bank or deposit transfer integration |
| Investment records, evidence history, liquidity and scenarios | SQLite and Flutter widget tests | PASS | Existing assessment and scenario suites plus tombstone history regression | Native workflow and investment onboarding breadth remain unverified |
| SQLite account isolation, export and legacy import transaction | SQLite FFI and widget tests | PASS | Owner isolation, export scope, pending queue guard, idempotent import, rollback on late conflict and disabled self-claim UI | Repository migration fixtures use known synthetic ownership. There is no trusted self-service recovery for real unowned data |
| Retry, pending edits, tombstones and account switches | Real SQLite with mocked cloud repository and auth | PASS | Five focused tests cover canonical IDs and timestamps, repeat upload after reopening SQLite, investment deletion and retained history, tombstone after a missing write, and in-flight account change | No remote revision precondition for ordinary upserts |
| Cloud identity, offline update and account isolation | Real Auth and Firestore emulators through Firebase JS | PASS | Fresh client downloads the original record, reconnects an offline update, and denies another account's read | Emulator JS test does not exercise Dart repositories or native plugins |
| Firestore ownership, deletion lock and immutable history | Firestore Emulator rules tests | PASS | Seven cases, including blocked cross-account tombstones, stale resurrection and immutable assessments | Production composite indexes and rule propagation remain unverified |
| Flutter SQLite → SyncService → real emulator | Native Flutter integration | BLOCKED | Added `integration_test/firebase_sync_test.dart`; analyzer passed | No Android SDK/device or Xcode in this workspace |
| App-level sync scheduling and cloud conflict decisions | App wiring inspection and targeted sync tests | FAIL | SyncService has no UI or lifecycle caller. Pending edits are protected during download, but ordinary uploads lack remote compare-and-set | Keep sync activation blocked pending a user-facing entry point and an explicit conflict strategy |
| Assistant and backend HTTP/SSE contract | Flutter widget/service tests and Node HTTP tests with deterministic OpenRouter | PASS | Assistant opening/history isolation, 23 backend cases including JSON, SSE, interruption, validation, deadline, disconnect, quota, CORS, rate limits and error redaction | Production OpenRouter and revoked-token behavior on the chat route are unverified |
| Backend validates current, expired and wrong-project credentials | Auth emulator and real Firebase Admin verification path | PASS | Existing backend accepts a genuine emulator token and rejects expired and wrong-audience emulator fixtures | Emulator tokens are unsigned. Production signing keys, chat-token revocation and HTTPS deployment were not exercised |
| Deletion lock, recursive cloud cleanup, Auth removal | Real backend, Firebase Admin and Auth/Firestore emulators | PASS | Lifecycle test retries cleanup, removes an orphaned assessment, preserves another owner's records, rejects recreation, then deletes the Auth account | Emulator Auth deletion is the JS client equivalent of the Flutter step |
| Deletion blocks pending changes, preserves local records on failure | SQLite FFI and mocked cloud cleanup | PASS | Focused deletion test verifies no remote call for pending writes, retention after remote failure, and local file removal after success | Combined native cleanup of encrypted files, preferences and keys remains unverified |
| Native SQLCipher creation, migration, separate keys, reopen and wrong key | Device integration tests | BLOCKED | `integration_test/account_encryption_test.dart` includes migration failure and retry with synthetic data | Run on Android/iOS/macOS. Linux SQLite FFI does not demonstrate encryption |
| Plaintext source retention and cleanup | SQLite tests and code inspection | PASS | Failed import leaves original intact. No automatic deletion or backup disposal was added | Original file stays plaintext until verified native recovery and separately authorized disposal |
| Android debug build | GitHub Actions on merged Stage 5 baseline | PASS | [Android build job](https://github.com/atre1des/SmartSave/actions/runs/45090394110/job/137418780924), successful steps, JDK 17 retained | Stage 6 build not yet verified. Local command exited 1 because Android SDK was missing |
| iOS no-codesign build | GitHub Actions on merged Stage 5 baseline | PASS | [iOS build job](https://github.com/atre1des/SmartSave/actions/runs/45090394110/job/137418780910), successful steps, entitlements and plugin registration preserved | Stage 6 build and native device execution require a macOS runner |
| Secret scanning and diff integrity | Gitleaks and Git | PASS | Redacted branch scan reported zero findings and `git diff --check` passed | New GitHub CI result remains separate |

## Defects corrected

- A stored empty `id` could override the authoritative Firestore document ID. Snapshot decoding now takes the ID from Firestore and normalizes server timestamp values used by existing update operations.
- Upload retries allocated fresh Firestore IDs. The client now stores the ID in SQLite before a network write, reuses it on retry and acknowledgment, and keeps newer queued edits unsynchronized. Upload/download results from an old account session cannot be applied through that session after an account switch.
- Holding and thesis saves could queue the update count as the record ID. The update and queue entry now share a transaction and use the original ID. Deletions write durable tombstones, reject stale resurrection in rules, suppress deleted records from active views, and retain thesis assessment history. Local edits still pending when a remote tombstone arrives remain a conflict. Pre-existing deletion operations whose remote IDs are unknown stay queued for review.
- Any signed-in account could claim unowned legacy records through the old confirmation dialog. The UI now shows that ownership cannot be established on-device and does not import either the shared database or its unscoped conversation history. Previous imports cannot be independently proven correct by this change.
- The AI proxy could wait indefinitely for an upstream provider or keep waiting after a client disconnected. It now enforces a two-minute deadline, cancels disconnected requests, and returns a retryable 504 before streaming headers when the deadline expires. Existing models, prompts and JSON/SSE contracts are unchanged.
- Adding the tombstone column could make a plaintext-to-encrypted migration compare old rows against extra destination defaults. Verification now compares the original fields and still verifies row counts and foreign keys.

## Release blocker register

| Severity | Issue | Release condition |
| --- | --- | --- |
| Critical | Native encrypted database migration, key recovery and deletion are insufficiently verified. Retained plaintext backups and old Firestore caches can persist on devices. | Run native integration and migration recovery tests on supported devices before authorizing any backup cleanup. Inspect upgrade and deletion artifacts on each device. |
| Critical | Original legacy data has no independent ownership evidence. Earlier self-claims may already have imported data into the wrong account. | Keep shared sources inaccessible to ordinary account import. Establish independently verified provenance and remediation before recovering or exposing records. |
| High | SyncService has no app-level caller. Offline cross-device writes lack revision preconditions, transaction/goal deletions are not reconciled on pull, and old unbound queue records cannot be matched safely. | Verify native end-to-end sync, establish remote conflict handling and an app entry point, then verify deletion/retry and role isolation before activation. |
| High | Combined native and cloud deletion has not been confirmed. The endpoint cannot erase other devices' caches, and an unclaimed legacy file intentionally blocks local deletion. | Verify the existing sequence in a disposable project with a native client. Keep production deletion disabled until cleanup and retry are proven. |
| Medium | Stage 6 Android and iOS CI jobs need review. Native profile and settings, layouts, and background/session restoration have remaining coverage gaps. | Run both CI jobs and run a real-device exploratory pass. |
| Medium | Production Firebase token signing, indexes, live OpenRouter and deployment-level CORS/limits are unverified. Chat token validation does not check revocation. | Verify supported deployment settings against a disposable project and agree on revocation and abuse controls. |

These findings prevent a production-readiness claim.

## Repeatable procedures

Use dependencies from the existing cache when possible. Run bounded commands from the repository root.

```bash
timeout 85s flutter pub get --enforce-lockfile
timeout 65s flutter analyze --no-pub
timeout 120s flutter test --coverage
timeout 60s node --test backend/test/server.test.mjs
timeout 90s firebase emulators:exec --project demo-smartsave-rules --only firestore 'node --test backend/test/firestore.rules.test.mjs'
timeout 90s firebase emulators:exec --project demo-smartsave-stage6 --only auth,firestore 'node --test backend/test/firebase.lifecycle.integration.mjs'
gitleaks git --redact --config .gitleaks.toml --log-opts=334de9fa7f103142ef11b21cd05ecccf73ddec9c..HEAD
git diff --check
```

For the emulator lifecycle test, use Node.js with the locked dependencies installed from `backend/package-lock.json`, Java 21 for the Firestore Emulator and Firebase CLI 15.11.0. Auth and Firestore bind to loopback only. The test refuses to run without loopback emulator endpoints and fixes the project to a disposable `demo-` ID. It uses a mocked OpenRouter response and deletes only synthetic emulator accounts. A password-reset or email-verification action link printed by the Auth emulator is disposable test data. Keep live deletion disabled.

For Android, install platform SDK API 36, JDK 17 and a compatible Android SDK/device. On macOS, ensure Xcode and CocoaPods are usable for iOS. Use separate terminals for the emulator and device commands.

```bash
flutter doctor -v
flutter doctor --android-licenses
flutter devices
flutter build apk --debug
flutter test integration_test/account_encryption_test.dart -d <android-device-id>
firebase emulators:start --project demo-smartsave-stage6 --only auth,firestore
flutter test integration_test/firebase_sync_test.dart -d <android-emulator-id>
```

On a physical Android device, run `adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8080 tcp:8080`, then pass `--dart-define=SMARTSAVE_EMULATOR_HOST=127.0.0.1` to the Firebase sync test. On an iOS simulator use the same define, and run the no-codesign validation with `flutter build ios --release --no-codesign` on macOS. Verify on device that logout and re-login reopen the correct encrypted file, another account cannot read it, and an interrupted migration leaves the original intact. Review any plaintext backup with its owner before disposal.

Run the deletion extension only on a disposable Firebase project. Review the rules, configure an HTTPS backend with credentials restricted to that disposable project, and enable deletion there only. Verify password reauthentication, handling of pending changes, retries under interrupted cleanup, database files and keys, preferences, Auth deletion, and inability to recreate cloud records. Record the actual native and cloud outcomes separately.
