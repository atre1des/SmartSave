# Stage 6.5 release blockers

Baseline is `da9cf0a5650be6816356e618fe3ab2469661b103`, the Stage 6 merge on `development`. Work is on `stage-6.5/release-blockers`. This report supersedes the relevant findings in [Stage 6 verification](STAGE_6_VERIFICATION.md). No production rule, backend, or account changes were performed.

## Verification matrix

| Requirement | Result | Evidence and limits |
| --- | --- | --- |
| App-level synchronization entry point | PASS | `main.dart` mounts `AccountSyncScope` inside the authenticated account's Riverpod container after its local repository opens. The widget regression mounts that entry point, verifies the UID and email-verification gate, and observes startup, committed local writes, debounce, background/resume, manual retry, reconnect signals and logout. The cloud connection is a fake in the widget test. |
| Offline edits, replay and newer acknowledgements | PASS | SQLite plus a deterministic cloud fixture covers two devices editing one record, reopening SQLite after a lost response, an older acknowledgement followed by a newer edit, an intervening remote edit, and a response arriving after an account switch. |
| Remote concurrency and tombstone rules | PASS | The Firestore Emulator allowed one of two competing transactions to write the same revision, rejected stale versions and resurrection, and preserved goal contributions and immutable investment assessments. The emulator rule test uses the Firebase JS client. The Dart Firestore transaction transport still needs native integration execution. |
| Transaction and goal deletion on pull | PASS | SQLite plus cloud fixture verifies transaction and goal tombstones hide the records on another device and restore the original balance without suppressing unrelated records. Remote absence is not used as evidence of deletion. |
| Legacy ownership and demos | PASS | Privacy still blocks self-service claiming. SQLite coverage verifies that historical self-claims cannot authorize deleting a shared original. Unattributed queued writes and writes without a recorded base revision stay local. New signed-in databases do not seed demo financial balances, transactions, goals or budgets. |
| Existing ownership provenance and retained plaintext disposal | BLOCKED | No independent ownership evidence for shared originals. Shared files and retained plaintext account backups block account deletion before its cloud callback. No backup disposal was performed. |
| Backend authorization, JSON/SSE and transport properties | PASS | 23 backend tests cover ID token gating, JSON/SSE, deadline, disconnect, sensitive-log checks and other existing contracts. The provider response and some auth paths are mocked. |
| Cloud deletion lifecycle | PASS | One disposable Auth/Firestore lifecycle test covers owner UID, cross-account isolation, authenticated cleanup of nested records, retry, deletion lock and Auth deletion. This runs the real backend with Firebase emulators and a mocked AI provider. |
| Local deletion fallback and pending-queue protection | PASS | SQLite FFI checks rejection before remote cleanup when pending operations or shared originals exist, and preserves local records on failure. Sync is suspended during account deletion. |
| Combined native encrypted-file, key and preference deletion | BLOCKED | Added an executable device integration test for a disposable emulator account. No Android/iOS device is available here. The widget confirmation and production HTTPS configuration also need device verification. |
| Native SQLCipher and secure storage, including backup recovery | BLOCKED | Preserved native migration, wrong-key, restart and isolation coverage and added checks for keys absent from SharedPreferences and the retained plaintext deletion guard. Cloud tests used SQLite FFI. |
| Android and iOS builds on the Stage 6 baseline | PASS | [Android Debug Build](https://github.com/atre1des/SmartSave/actions/runs/45142899801/job/137585456943) and [iOS No-Codesign Build](https://github.com/atre1des/SmartSave/actions/runs/45142899801/job/137585456911) show successful completion. JDK 17 is unchanged. |
| Stage 6.5 native builds | BLOCKED | The workspace exposes Linux only and lacks Android SDK, Android device tooling, and Xcode. This branch requires its own native CI run. |
| Flutter dependency resolution, analyze and coverage | PASS | Locked resolution exit 0. Analyzer exit 0 with zero diagnostics. Full Flutter coverage suite exit 0 with 48 passed and an LCOV file. |
| Firestore rules and diff verification | PASS | Nine Firestore rule tests passed with exit 0. Redacted Gitleaks branch scan and `git diff --check` exited 0. |

## How synchronization behaves

A verified Firebase UID mounts exactly one scheduler for the account repository. The scheduler requests a pass at startup and after a local financial change, a Firestore server-backed reconnect signal, resume, or **Privacy & data → Sync financial records**. It debounces local writes, serializes passes, and has three bounded backoff attempts after a transient error. It does not continuously poll. On logout or switching accounts the scheduler cancels its timers and subscriptions. The service rejects stale account results and each Firestore transaction checks the captured UID before writing. Native Firestore reconnect behavior still needs a real device run.

A new local record receives a stable cloud ID and base revision zero. A pulled record records the server revision. Before upload the queue freezes the expected revision and sends its immutable payload using the operation ID as a retry marker. Firestore checks the expected revision inside a transaction. The identical retry is acknowledged only at its exact resulting revision. SQLite records that revision and removes only the acknowledged operation in one transaction. A later queued edit remains unsynced. A stale revision, unattributed owner, missing identity, or unavailable legacy base never turns into a last-write-wins update. The app reports that the records need review. The queue retains both the pending local change and its reference to the remote record.

Transaction, goal, holding, and thesis deletions use revisioned tombstones. Pull hides inactive records and excludes deleted transactions from balances and spending. A newer tombstone cannot replace a pending local edit. Rules prevent resurrection and hard deletion of goal documents by clients. Assessments and linked goal contribution history are preserved. Older hard deletions and unlinked queued operations are not guessed from absence. Goal balance updates include the saved total, but individual contribution records and thesis assessments are not new synchronized entities in this stage.

## Remaining release blockers

| Severity | Blocker | Required evidence |
| --- | --- | --- |
| Critical | Native encrypted migration, restart, key lookup, and removal are unverified. Old plaintext backups remain present. | Pass the native tests and inspect artifacts on each supported target before separately authorizing any disposal. |
| Critical | Shared legacy data and historic self-claims lack independent ownership evidence. | Keep the old files private. Require independently verified provenance and an owner-approved recovery or remediation plan. Do not guess ownership, delete evidence, or use account login as proof. |
| High | Complete encrypted local and cloud deletion remains unverified. A shared or retained plaintext original can block deletion deliberately. | Execute the disposable device deletion test, verify the existing confirmation and HTTPS endpoint in an isolated staging app, and resolve outstanding backup ownership. Keep production deletion disabled. |
| High | Native SQLite-to-Firestore sync and actual reconnection must be validated. There is no conflict-merging UI and unknown legacy IDs or revisions stay queued. | Pass the device emulator procedure below, exercise two devices, verify pending operations survive losing edits, and plan independent reconciliation for unknown legacy data before expecting it to upload. |
| High | Existing account files may still contain historical sample or shared records and per-contribution and assessment history is not synchronized across devices. | Review existing accounts with their owners and confirm what history the release promises to restore. Never clear old data based on the new-account seed policy. |
| Medium | Stage 6.5 Android and iOS CI and native staged rollout are pending. | Verify the PR checks before rollout and deploy reviewed rules only through a separate authorized release process. |

## Reproduce the cloud checks

Run these from the repository root using the existing dependencies and Firebase CLI 15.11.0. Use Java 21 for the Firestore Emulator, independently of Android's JDK 17.

```bash
timeout 65s flutter pub get --enforce-lockfile
timeout 60s flutter analyze --no-pub
timeout 120s flutter test --coverage
timeout 50s node --test backend/test/server.test.mjs
timeout 90s firebase emulators:exec --project demo-smartsave-rules --only firestore 'node --test backend/test/firestore.rules.test.mjs'
timeout 90s firebase emulators:exec --project demo-smartsave-stage6 --only auth,firestore 'node --test backend/test/firebase.lifecycle.integration.mjs'
gitleaks git --config .gitleaks.toml --redact --log-opts=da9cf0a5650be6816356e618fe3ab2469661b103..HEAD
git diff --check
```

## Android Studio and Windows PowerShell

In Android Studio **Tools → SDK Manager**, install Android SDK Platform 36, Android SDK Platform-Tools, Android SDK Command-line Tools, and Android Emulator. Create and start an API 24 or newer emulator in **Device Manager**. Use the Flutter 3.41.7 SDK and Temurin JDK 17. Substitute your installed Temurin path and the device ID printed by `flutter devices`.

```powershell
Set-Location C:\path\to\SmartSave
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:Path = "$env:ANDROID_HOME\platform-tools;$env:Path"
$env:JAVA_HOME = 'C:\path\to\Temurin-17'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
flutter config --jdk-dir="$env:JAVA_HOME"
flutter doctor -v
flutter doctor --android-licenses
flutter pub get --enforce-lockfile
flutter devices
$device = 'emulator-5554'
flutter build apk --debug
flutter test integration_test/account_encryption_test.dart -d $device
```

In a second PowerShell window, use Java 21 and run the disposable emulator backend. The Firebase emulators bind to loopback. Restrict inbound port 3001 to your test host with Windows Firewall before starting the backend. Stop it when finished. Do not run this command from a production environment.

```powershell
Set-Location C:\path\to\SmartSave
$env:JAVA_HOME = 'C:\path\to\JDK-21'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
npm --prefix backend ci
$env:FIREBASE_PROJECT_ID = 'demo-smartsave-stage6'
$env:SMARTSAVE_ENABLE_ACCOUNT_DELETION = 'true'
$env:PORT = '3001'
npx --yes firebase-tools@15.11.0 emulators:exec --project demo-smartsave-stage6 --only auth,firestore "node backend/server.js"
```

Back in the JDK 17 window, target the running emulator:

```powershell
flutter test integration_test/firebase_sync_test.dart -d $device
flutter test integration_test/account_deletion_emulator_test.dart -d $device --dart-define=SMARTSAVE_EMULATOR_DELETION=true
```

For a physical Android test device use its ID, run `adb -s $device reverse tcp:9099 tcp:9099`, `adb -s $device reverse tcp:8080 tcp:8080`, and `adb -s $device reverse tcp:3001 tcp:3001`. Add `--dart-define=SMARTSAVE_EMULATOR_HOST=127.0.0.1` to both Firebase test commands. The native deletion test explicitly targets only the disposable project and uses HTTP on emulator loopback. It does not exercise the app's production HTTPS transport or UI confirmation.

For iOS, run `flutter build ios --release --no-codesign` on macOS with Xcode and CocoaPods. Use `flutter test integration_test/account_encryption_test.dart -d <ios-device-id>` on a supported target. For the Firebase tests on a local iOS simulator use `--dart-define=SMARTSAVE_EMULATOR_HOST=127.0.0.1`. Before release, separately verify the confirmation UI and combined lifecycle through a disposable app build and trusted HTTPS test backend. Do not enable deletion on production or dispose of a plaintext original solely because a build or emulator test passed.
