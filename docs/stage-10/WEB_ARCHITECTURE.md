# Stage 10 · Web architecture and release plan

For the current authenticated build and separate review entry point, see [Phase B verification](PHASE_B_VERIFICATION.md). The material below records Phase A.

## Review boundary

The native startup and storage path remains the mobile path. The web entry uses a separate Flutter shell selected by a conditional import, so opening the browser does not invoke native SQLite or the account sync scope. The default build renders an explicit unavailable state. Adding `--dart-define=SMARTSAVE_WEB_REVIEW=true` enables the fictional workspace. There is no runtime switch from the authenticated application into the fixture.

The review shell uses the UI v3 charcoal palette, glass dock, grouped records, editorial type and financial figures. At 1024 logical pixels a sidebar replaces the dock. Financial columns begin at 720 logical pixels of usable content. The chat gets an inline history panel at 790 pixels of workspace width. Smaller widths open history as a sheet. Pages share a bounded content measure and keep the selected section and draft memory when changing widths.

`WorkspaceData` is a read-only presentation contract injected into the Home and Invest views. `FictionalWorkspace` is its only adapter. Theme is device-wide and persisted by the existing appearance controller. Locale is a tab-level preview selection. Messages added using the composer are in-memory drafts.

## Authenticated Phase B adapter

Initialize FlutterFire explicitly with the intended web FirebaseOptions. The generated repository config points to `smartsave-dev-3a1f5`; verify the review project, app ID, Auth provider enablement and authorized origins with a disposable project before enabling the real session. FirebaseOptions are public client identifiers. Firebase Admin credentials stay in the backend. Use Firebase Auth SESSION persistence and rebuild the complete state scope on UID changes. Cancel listeners and writes in flight and discard rendered snapshots, selected records, drafts and out-of-date results after logout or account change.

Use Firestore with durable browser persistence disabled. Read under `users/{uid}` with the existing deployed rules validated in the emulator, and require server-confirmed reads for actions that depend on freshness. Show offline or unavailable explicitly; disable durable writes when server acknowledgement cannot be obtained. Repository methods should return distinct conflict, unavailable and permission outcomes. Use owner-scoped document IDs, bounded queries, stable operation IDs where retry is possible, and Firestore transactions comparing the existing revision before updating. Never bulk replace from a cached snapshot. Contribution and transaction retries must remain idempotent across ambiguous acknowledgements. Use account isolation, malformed-write, concurrent-edit and offline tests before enabling each operation. There is no automatic native migration. Export must be explicit from an authorized snapshot and contain only the current account.

## AI boundary

Use the existing provider and Firebase ID-token interceptor behind an authenticated session. Browser streaming uses Fetch ReadableStream for `ResponseType.stream`, preserving the native adapter and existing SSE parser. It omits cookies, rejects redirects, bounds header and idle waits and cancels the browser request on stream disposal or adapter close. Authenticated completion requests also use Fetch for non-stream responses, so the same redirect policy applies. Health probes retain Dio’s browser adapter. Retain model selection on the server. The review workspace does not call Render or Firebase. Test CORS and status mapping with disposable credentials before wiring signed-in Chat.

Render's existing `SMARTSAVE_ALLOWED_ORIGINS` is an exact list. The operator must authorize the intended browser origin, including the scheme and port where applicable. Preflight must allow POST, Authorization and Content-Type, and the response must expose Retry-After. Use HTTPS for any authenticated environment. Never pass an OpenRouter key or an admin key through Dart defines or web assets.

## Future static hosting procedure

1. Build an environment-specific release from the tested commit using `flutter build web --release --no-web-resources-cdn --pwa-strategy=none`. For a non-root mount, set `--base-href=/subpath/`. A deployment build must omit `SMARTSAVE_WEB_REVIEW`.
2. Configure the chosen static host to serve `build/web` over HTTPS. For Firebase Hosting, set that directory as public and rewrite app routes to `index.html`, while serving existing assets directly. Keep deployment configuration specific to the authorized test or release project.
3. Add the HTTPS host to Firebase Authentication authorized domains. Coordinate approval of the exact origin in the Render CORS allowlist and verify preflight and streaming with a disposable account.
4. Revalidate HTML, bootstrap, manifest and version metadata on each request. Keep immutable caching for content-hashed assets only. Avoid caching authenticated responses. If a service worker is introduced later, verify activation, updates, old-cache eviction, and logout behaviour.
5. Retain the previous static release. On regression, roll back to that version through the authorized host, or republish its exact build artifact. Test reloading an existing browser session after the rollback.

No hosting, Firebase or Render changes were applied.
