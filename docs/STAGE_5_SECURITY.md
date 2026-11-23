# Stage 5 security review

## Backend and Firestore

Install the locked Node dependencies with `npm --prefix backend ci`. Set `FIREBASE_PROJECT_ID` to the same project as Flutter and inject `OPENROUTER_API_KEY` through the backend runtime. Keep private environment and service-account files out of Git. The committed Firebase client configuration is public. Serve the backend over HTTPS and build the app with `--dart-define=SMARTSAVE_BACKEND_URL=https://your-proxy-host`. For browser clients, set `SMARTSAVE_ALLOWED_ORIGINS` to a comma-separated list of exact origins.

Health and model metadata are public. Completions require a Firebase ID token. The proxy limits traffic to 120 attempts per IP and 30 authenticated requests per UID per minute in one process. Configure shared limits at ingress for multi-instance deployment.

Deletion uses a separate route that verifies a non-revoked Firebase token with an authentication age under five minutes. It scopes all operations to the verified UID. Enable it with `SMARTSAVE_ENABLE_ACCOUNT_DELETION=true` only after the deletion-lock rules have been independently reviewed and deployed to the same project and the backend has Firebase Admin credentials to verify token revocation and recursively delete Firestore documents. Use Application Default Credentials. The handler writes a server-owned lock, then deletes the entire `users/{uid}` subtree, including orphaned subcollections, and responds successfully only once cleanup completes. The minimal UID lock remains so outstanding client writes cannot recreate deleted records. Never enable this route against production as part of testing.

## Encryption and recovery

Android, iOS and macOS use a single SQLCipher Flutter driver for native SQLite. Android support starts at API 24 in this app. Account passwords are generated from 32 secure random bytes and stored by the platform-backed secure storage plugin. The app checks that a newly stored key can be read back before using it. It checks for SQLCipher on open and queries SQLite metadata with the key. Missing keys, unsupported schemas, and migration failures prevent the protected account from opening. Linux repository tests use the existing SQLite FFI driver. Linux, Windows and web do not have an app-encryption verification claim.

The account-specific plaintext database, if present, is read without modifying it. Migration copies the supported rows and sequence values to a new encrypted file in one transaction, verifies row values and foreign keys, and marks completion only at commit. The original plaintext backup remains on disk and is not protected by SQLCipher. Preserve it until verified recovery and decide backup disposal with the owner. Do not copy it into a public backup or support bundle.

Privacy & data offers explicit legacy recovery for a single-owner installation. A claim on the device is reserved to that UID before import. Records linked to another UID, overlapping records with different values, duplicate cloud IDs, and mismatched assistant history stop the import. An untouched fictional seed snapshot may be replaced by legacy rows. A modified account database is never automatically overwritten. Import is transactional and the original database and SharedPreferences history are retained. Stable IDs and valid queue entries are preserved. Unowned queue operations stay unowned and Stage 4B does not upload them. Mixed-account and conflicting snapshots require case-by-case ownership and record reconciliation.

## Account lifecycle and export

Deletion asks for explicit confirmation and the account password. The app holds the local database transaction while checking for pending work and requesting cloud cleanup. Pending work and unclaimed legacy databases stop progress. After cloud success, the app seals the local repository against new writes, clears local account preferences, removes its database files and key, then deletes Firebase Authentication. The seal lets a restart resume local cleanup after a partial failure. Previously recovered shared records and history are removed only for their confirmed owner. No request can erase caches on other devices. Verify any historical Firestore caches and backups on each device separately.

Privacy & data exports the current account's local financial cache as versioned JSON with an export timestamp, stored record IDs, timestamps and amounts. The export omits credential storage, preferences, internal queue payloads, and assistant conversations. The user can explicitly copy the JSON to the clipboard. It contains private financial data and is not a live Firestore export.

## Verification

From the repository root:

```bash
flutter analyze
flutter test --no-pub test/sync_foundation_test.dart test/finance_repository_sync_test.dart test/account_database_security_test.dart test/account_recovery_export_test.dart test/financial_assistant_service_test.dart test/financial_assistant_screen_test.dart test/assistant_bubble_widget_test.dart
node --test backend/test/server.test.mjs
firebase emulators:exec --project demo-smartsave-rules --only firestore 'node --test backend/test/firestore.rules.test.mjs'
```

Node tests mock Firebase token verification, cloud deletion and OpenRouter. Firestore rule tests use synthetic identities on a demo emulator project.

For native Android verification, install Android SDK Platform 36, compatible build-tools, and an API 24+ emulator or connect a test device. Use Flutter 3.41.7 and run:

```bash
flutter doctor -v
flutter doctor --android-licenses
flutter pub get --enforce-lockfile
flutter devices
flutter test integration_test/account_encryption_test.dart -d <android-device-id>
flutter build apk --debug
```

The integration test uses synthetic rows and verifies plaintext migration and preservation, a non-plaintext header, incorrect-key rejection, and a reopen through platform secure storage. Run the same test on iOS and macOS with their supported Xcode toolchain and signing configuration. On a disposable Firebase test project with reviewed deletion-lock rules, verify sign-in, offline reopen, logout and switching, a real authenticated HTTPS assistant stream, and deletion with pending work, partial failure, and successful retry. Verify Firestore, Auth and local files separately. Do not use live user accounts.
