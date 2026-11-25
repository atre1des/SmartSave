# Stage 10 · Web compatibility audit

Base `ac70823071b27b77e4c229dbda2df6fef3c2259b`. This audit covers the default entry point, account lifetime, persistence, finance features, AI request path, Flutter plugins and browser host files.

| Area | Class | Evidence and Phase A decision |
| --- | --- | --- |
| Flutter widgets, charts, SVG, Markdown, locale, themes | A | Renderer-compatible APIs already exist. Reuse UI v3 tokens, dock, shared formatting and delegates. Browser interaction and size checks are separate from build verification. |
| Device theme preference | A | Shared Preferences has a web implementation. Store only theme. Preview locale belongs to the current tab and never affects an authenticated account. |
| Firebase client libraries | B | FlutterFire Auth and Firestore support web. Generated options target `smartsave-dev-3a1f5`. Existing initialization calls Firebase without options and relies on mobile configuration. Supply explicit FirebaseOptions for an isolated web project in Phase B. |
| Browser sign-in, persistence and switching | B | AuthService already chooses SESSION persistence on web. Existing signed-in startup immediately opens a native repository. UID changes must replace the full provider scope, stop listeners and discard cached state. Real browser auth remains gated in Phase A. |
| Native SQLite/SQLCipher, secure storage | C | FinanceRepository uses sqflite, SQLCipher on supported native platforms and file operations for database management. The guarded platform check only avoids SQLCipher selection and does not provide a browser database. Browser storage offers no equivalent encryption guarantee. |
| Firestore reads and writes | B | Existing FirestoreRepository binds requests to an expected UID and rules scope the paths. The sync service reconciles with a native DB and cannot run independently of it. Phase A does not open a Firestore connection. |
| Goals, contributions, transactions, budgets, holdings, theses | B | Financial arithmetic is portable. Controllers depend on the native repository for reads and write ordering. Use server-backed contracts and explicit conflict outcomes before enabling writes. |
| Deposits and market examples | A/B | Existing product and market copy explicitly states sample coverage. A Phase A fixture demonstrates layout. Live products, trades or quotes are outside this stage. |
| Export, recovery and migration | C | Native backup paths, encrypted archives and legacy ownership checks are device-specific. Browser export requires an account-scoped, server-confirmed snapshot and an explicit download. No automatic import. |
| AI configuration and transport | B | Native client obtains a UID-checked Firebase ID token and has an SSE parser. Dio 5's locked dio_web_adapter 2.2.2 sets XHR responseType to arraybuffer and constructs ResponseBody after load. Passing ResponseType.stream alone doesn't stream. Browser Fetch with ReadableStream requires cancellation, no redirects, deadlines, and explicit CORS. |
| AI transcripts and assistant fallback | B | Both depend on the native FinanceRepository. Review transcripts are fictional, and review sends are temporary drafts. No fabricated assistant replies. Authenticated storage and live CORS verification require Phase B. |
| dart:io and native plugins | B/C | FinanceRepository uses Directory, File and Platform. Legacy ai/config.dart uses Platform.environment, and ai/market_data.dart imports dart:io. The preview uses a conditional web entry and never calls native storage. Crashlytics remains native. No browser secret configuration from native environment readers. |
| Browser clipboard and file access | B | Clipboard depends on browser permissions and secure context. Native file paths and export mechanisms have no direct web equivalents. |
| Web host and browser targets | B | Existing web/index.html and manifest were scaffolding with a portrait lock. Phase A adds viewport metadata and supports browser resizing. Actual Safari and Windows/macOS browser coverage remains separate from headless Chromium. |

A indicates a portable foundation. B requires web implementation or verification. C is unavailable until a safe design is verified.
