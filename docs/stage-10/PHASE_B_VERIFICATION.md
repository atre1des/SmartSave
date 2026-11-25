# Stage 10 Phase B · Authenticated Flutter Web

Phase A base `aa853b69b7d2f77f8bd2d9420e8f82c58d075a2e`. The web workspace retains the approved desktop sidebar, compact dock, charcoal palette, grouped records, and chat history and composer layout.

## Feature parity

| Area | Browser support |
| --- | --- |
| Authentication | Email registration, verification, sign-in, password recovery, sign-out and Firebase SESSION restoration. A verified user is required before the workspace opens. |
| Overview and spending | Server-read transaction ledger, net recorded balance, recent records, local-calendar monthly spending and categories, budgets and goal progress. An opening balance stored only in native SQLite is unavailable here. |
| Financial records | Create, edit and soft-delete transactions and goals. Add contributions and create or edit budgets. The transaction and contribution operations reuse an operation ID on retry. |
| Investment records | Read saved thesis summaries and holdings from the current account. Detailed research editors, assessments and market feeds remain unavailable. |
| Assistant | Existing Firebase token interceptor, Fetch SSE, Markdown, recent conversational context, multilingual mode, history and cloud saves. Local browser verification uses an authenticated emulator fixture. |
| Account settings | Account-scoped locale, device-wide theme, server-refresh, and scoped financial JSON export with explicit copy. Export covers top-level financial records and excludes credentials, child records and conversations. |
| Mobile-specific features | Native deposit workflows, encrypted backup recovery, native-only opening balance and web account deletion controls remain unavailable in the browser. No automatic migration. |

## Session and data model

The regular entry point uses explicit Firebase Web client configuration; the existing native initialization and SQLite/SQLCipher path are kept on native platforms. Firebase Auth uses SESSION persistence. The emulator build sends recovery requests directly to its loopback Auth API. The regular build uses FlutterFire for password recovery. The web session owns a Navigator and repository keyed by Firebase UID. Switching or signing out removes the entire account UI, including its modals. The repository checks the current verified UID before and after asynchronous work. In-flight Firestore work whose result arrives after a session change is discarded. Session teardown cancels browser connectivity subscriptions and the AI stream and closes the AI client.

Every read uses `Source.server` and rejects cache or pending-write snapshots. Persistent Firestore browser caching is disabled. The SDK may keep transient memory during the tab session; the web app exposes records only after UID-bound server reads. Each collection is capped at 1,000 documents for Phase B. Data beyond this cap produces an explicit unavailable result, so totals stay complete. Snapshots are loaded by collection rather than a single cross-collection transaction. Offline writes require an online session and a Firestore transaction. There is no browser write queue or silent sync from plaintext files.

Edits compare the version held by the editor with the server version inside the transaction. The losing edit stays in the form and shows a conflict. A contribution and its goal increment share one transaction. The target record and an immutable owner-only marker are committed together. Replaying an operation with the same payload is a no-op. Reusing it with a different payload causes a conflict. Markers store a digest and target path. Operation retry after an ambiguous failure uses the current editor's operation ID. Reloading a page discards the unsaved editor, so check the refreshed ledger before resubmitting an ambiguous operation.

Web conversations and locale use owner-only rule paths with bounded payloads and revisions. Completed replies are saved under the same UID; a failed save can be retried without sending the prompt again. The renderer disables remote Markdown images. The preview fixture now requires the separate `lib/web_review.dart` entry point. The normal deployment target has no review flag or runtime route into it.

## Manual configuration

Use Flutter **3.41.7** and Dart **3.11.5**. For native feature comparison, use the existing local mobile setup. For an isolated HTTPS web project, create a Firebase Web app, enable Email/Password auth, add the intended origin’s host to Auth authorized domains and enable Firestore. Install the reviewed rules in the isolated project through its authorized owner. The new browser-only collections require the updated rules. Review the browser settings, operation markers and conversation cleanup with account deletion before any public rollout.

Build the normal entry with the five public client configuration values supplied by the isolated web app. Keep Firebase Admin credentials, tokens and OpenRouter keys out of the build.

```sh
flutter pub get --enforce-lockfile
flutter build web --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=SMARTSAVE_FIREBASE_PROJECT_ID="<project-id>" \
  --dart-define=SMARTSAVE_FIREBASE_APP_ID="<web-app-id>" \
  --dart-define=SMARTSAVE_FIREBASE_API_KEY="<public-web-client-key>" \
  --dart-define=SMARTSAVE_FIREBASE_SENDER_ID="<sender-id>" \
  --dart-define=SMARTSAVE_FIREBASE_AUTH_DOMAIN="<project-auth-domain>"
```

The default AI origin is `https://smartsave-sl61.onrender.com`. Verify the proxy trusts the same Firebase project before choosing an endpoint for an isolated test. The proxy operator must approve the exact HTTPS web origin in `SMARTSAVE_ALLOWED_ORIGINS` and expose `Retry-After`. The existing Render service and rules deployment were left untouched. **LIVE RENDER VERIFICATION BLOCKED** pending an authorized matching project, origin and disposable sign-in.

## Reproduce the local browser checks

Start the emulators with Firebase CLI and Java 21. Use the demo project named below. Start the local SSE fixture and web server in separate terminals.

```sh
firebase emulators:start --only auth,firestore --project demo-smartsave-web --config firebase.web-emulators.json
python tool/stage10/local_ai_fixture.py
```

```sh
flutter build web --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=SMARTSAVE_WEB_EMULATORS=true --output build/stage10b-emulator
flutter build web --no-web-resources-cdn --pwa-strategy=none \
  --base-href /probe/ --target tool/stage10/repository_probe.dart \
  --output build/stage10b-emulator/probe
python -m http.server 8613 --bind 127.0.0.1 --directory build/stage10b-emulator
```

Run the Playwright test with Python and Chromium installed. `SMARTSAVE_BROWSER_BINARY` optionally sets the Chromium executable, and `SMARTSAVE_FIREBASE_SDK_MIRROR` accepts a directory with trusted copies of FlutterFire's pinned Firebase JS 11.9.1 app, auth and firestore modules when the CDN is blocked. The mirror only applies to the browser test. Provide `SMARTSAVE_TEST_SCREENSHOTS` to save captures.

```sh
SMARTSAVE_TEST_REPLAY_PROBE=1 python tool/stage10/browser_test.py
```

## Browser evidence and limits

[Home light](phase-b/authenticated-home.png) · [Home charcoal](phase-b/authenticated-home-dark.png) · [Streaming chat](phase-b/authenticated-chat.png)

Captures use a disposable Firebase Auth and Firestore emulator account. The SSE fixture checks the Firebase emulator token and streams delayed Kazakh and Russian chunks. The browser verifies that the first chunk is visible before the second arrives, then checks history reload and HTTP 401 and 429. These checks do not send traffic to Render or OpenRouter. Firefox, Safari, mobile browser hardware, and live production services remain unverified.

## Verification record

| Check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Exit 0 |
| `flutter analyze --no-pub` | Exit 0, zero diagnostics |
| `flutter test --no-pub --coverage` | Exit 0, 66 passed |
| `flutter build web --no-pub` | Exit 0 |
| Backend proxy suite | Exit 0, 27 passed |
| Firestore emulator rules suite | Exit 0, 11 passed |
| Browser integration | Exit 0 in Chromium. Covers registration, verification, recovery, session restoration, scoped writes, stale edits, duplicate operations, offline rejection, saved locale and export, compact resize, simulated page scaling, SSE, conversational history and account switching. |
| Repository browser probe | Exit 0. Independently verified replay, edit and soft-delete operations and budget revisions. |
| Whitespace and Gitleaks | Exit 0 for both. |
