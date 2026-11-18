# SmartSave — Production Readiness Audit & Firebase Migration Plan

**Date**: 2026-11-18  
**Deadline**: December 10, 2026 (22 days)  
**Status**: Read-only audit complete — ready for implementation planning

---

## 1. Actual Architecture

### 1.1 Technology Stack
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

### 1.2 Application Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                      SmartSave App (Flutter)                    │
├─────────────────────────────────────────────────────────────────┤
│  Features (5 tabs)                                              │
│  ├── Home (Dashboard, Spending Analytics, Transactions)         │
│  ├── Goals (Savings goals, contributions, progress)             │
│  ├── Deposits (Sample rate catalog, comparison, calculator)     │
│  ├── Invest (Investment Intelligence, Stocks, Bonds, Auto)      │
│  └── My Account (Profile, Settings, Privacy, Subscription)      │
├─────────────────────────────────────────────────────────────────┤
│  Data Layer                                                     │
│  ├── FinanceRepository (SQLite operations)                      │
│  ├── FinanceController (Riverpod ChangeNotifier)                │
│  ├── Models (Transaction, Goal, Thesis, Holding, etc.)          │
│  └── Providers (Riverpod DI)                                    │
├─────────────────────────────────────────────────────────────────┤
│  Local Persistence                                              │
│  ├── SQLite (smartsave_demo.db) — Financial data               │
│  └── SharedPreferences — Auth flags, profile, settings          │
├─────────────────────────────────────────────────────────────────┤
│  External Services (Current)                                    │
│  ├── OpenRouter Proxy (backend/) — AI assistant only            │
│  └── NO Firebase, NO Cloud Firestore, NO Auth backend           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Key Design Decisions
- **Integer currency**: All amounts stored as integer tenge (₸) to avoid floating-point errors
- **Repository pattern**: UI never issues SQL directly; FinanceRepository owns all queries
- **Riverpod DI**: `financeRepositoryProvider` and `sharedPreferencesProvider` overridden in `main.dart`
- **Deterministic seed data**: Demo data seeded on first run; reset restores exact same records
- **Free-tier AI only**: Backend enforces `:free` model suffix; rejects paid models

---

## 2. Actual Git Status

| Aspect | Status |
|--------|--------|
| **Git initialized?** | Yes (`.git` exists) |
| **Commits?** | **None** — "No commits yet on master" |
| **Remote configured?** | **No** — `git remote -v` returns empty |
| **Branch** | `master` (default) |
| **Uncommitted changes** | All files untracked (2406+ files) |
| **.gitignore** | Present, excludes `.env`, `node_modules`, `build/`, `.dart_tool/` |
| **Secrets tracked?** | **No** — `.env` is gitignored; API key only in local `.env` |

### 2.1 Files Requiring Commit
All project files are currently untracked. Key files to commit:
- `pubspec.yaml`, `pubspec.lock`
- `lib/` (entire source tree)
- `backend/package.json`, `backend/server.js`
- `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`
- `test/`, `docs/`, `assets/`
- `analysis_options.yaml`, `.gitignore`

### 2.2 Files to Keep Ignored
- `.env` (contains OpenRouter API key)
- `build/`, `.dart_tool/`, `.flutter-plugins-dependencies`
- `node_modules/`, `backend/node_modules/`
- IDE folders (`.idea/`, `.vscode/`)

---

## 3. Existing Functionality (Implemented)

### 3.1 Core Financial Features ✅
| Feature | Status | Implementation |
|---------|--------|----------------|
| **Transactions** | Full CRUD | Create, read, filter, search, edit, delete |
| **Spending Analytics** | Complete | Category breakdown, donut chart, month-over-month comparison |
| **Budgets** | Full CRUD | Per-category monthly limits, over-budget alerts |
| **Balance Calculation** | Working | Opening balance + net transactions |
| **Savings Goals** | Full CRUD | Create/edit/delete, progress %, deadline, contributions |
| **Goal Contributions** | Working | Manual add, updates goal saved amount |
| **Deposit Catalog** | Complete | Sample products, filters (term, top-up, withdrawal, capitalization) |
| **Deposit Calculator** | Working | Simple interest: `principal × nominal_rate_bps × months / 120000` |

### 3.2 Investment Intelligence ✅
| Component | Status | Details |
|-----------|--------|---------|
| **Investment Theses** | Full CRUD | Security name, ticker, exchange, rationale, horizon, assumptions, risks, invalidation conditions |
| **Thesis Conditions** | Full CRUD | Description, metric, comparator (atLeast/atMost), threshold, observed value, period, source, evidence note |
| **Thesis Assessments** | Immutable history | Dated snapshots with condition evaluations, bear-case review, assessment history |
| **Evidence Evaluation** | Rule-based | Numeric: compares observed vs threshold; Qualitative: always `Insufficient` without source/period |
| **Portfolio Holdings** | Full CRUD | Security, ticker, market value (KZT), FX/oil/rate sensitivities (optional) |
| **Liquidity Analysis** | Working | Order size vs historical volume → volume multiple, participation scenario, days to liquidate |
| **Economic Ripple** | Working | Three scenarios (tenge depreciation, oil price decrease, rate increase) with user-entered sensitivities |
| **Investment Settings** | Key-value store | Scenario type, magnitude persisted in SQLite |

### 3.3 Authentication & Onboarding (Simulated/Demo) ⚠️
| Screen | Status | Notes |
|--------|--------|-------|
| Welcome | Implemented | Figma-based splash with SVG assets |
| Sign Up / Sign In | Implemented | **Demo only** — accepts any email/password (≥8 chars), stores in SharedPreferences |
| Onboarding (3 steps) | Implemented | Track/Save/Grow carousel; **2 of 3 steps not in Figma** |
| Connect Card | Implemented | **Simulated failure** — no real bank connection |
| Risk Quiz (5 questions) | Implemented | **4 of 5 questions not in Figma**; always returns "Moderate" profile |
| Risk Profile Result | Implemented | Shows 60/25/15 allocation (deposits/bonds/stocks) |

### 3.4 Profile & Settings ✅
| Feature | Status | Storage |
|---------|--------|---------|
| Profile Details | Editable | SharedPreferences (name, email, country, currency, language) |
| Connected Accounts | Demo UI | Toggle connect/disconnect; no real sync |
| Notifications | Toggle switches | SharedPreferences (5 categories) |
| Advice History | Display only | Seeded sample data from SQLite |
| Privacy & Data | UI only | Consent toggles; export not implemented; delete clears local data |
| Subscription | Demo preview | Free/Premium tiers; no billing |
| Help & FAQ | Implemented | Searchable local FAQ list |
| Reset Demo Data | Working | Truncates & reseeds SQLite tables |
| Delete Account | Working | Clears SharedPreferences + resets demo data |

### 3.5 AI Assistant (Local Rule-Based) ⚠️
| Mode | Status | Notes |
|------|--------|-------|
| Streaming via OpenRouter | Implemented | Backend proxy required; free-tier models only |
| Local Fallback | Implemented | Keyword-based responses when backend unavailable |
| Financial Context Injection | Working | Pulls balance, budgets, goals, deposits, theses, holdings from repository |
| Beginner/Experienced Modes | Implemented | Different system prompts per mode |

### 3.6 Tests ✅
| Test File | Coverage |
|-----------|----------|
| `finance_repository_test.dart` | 4 tests: dashboard totals, transaction CRUD, goal contributions, deposit filters + reset |
| `investment_intelligence_test.dart` | 5 tests: thesis/conditions/assessments, evidence classification, liquidity, economic scenarios, holdings persistence |
| `financial_assistant_service_test.dart` | AI service tests |
| `financial_assistant_screen_test.dart` | UI tests |
| `assistant_bubble_widget_test.dart` | Widget tests |
| `widget_test.dart` | 4 tests: formatting, arithmetic, repository, UI |
| `app_flow_test.dart` | Journey tests (timed out in Windows) |
| `investment_intelligence_widget_test.dart` | Widget tests |

---

## 4. Missing Functionality (Production Gaps)

### 4.1 Authentication & User Identity ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No real authentication** | **Critical** | Current auth is simulated; no Firebase Auth, no email verification, no password reset, no OAuth |
| **No user identity** | **Critical** | No user UID; data not scoped to user; multi-user impossible |
| **No secure credential storage** | **High** | SharedPreferences stores demo credentials in plaintext |
| **No session management** | **High** | No token refresh, no logout sync, no device management |
| **No account recovery** | **Medium** | Forgot password shows "unavailable in demo" |

### 4.2 Cloud Persistence & Sync ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No Cloud Firestore** | **Critical** | All data local only; no cloud backup, no cross-device sync |
| **No synchronization service** | **Critical** | No upload/download, no conflict resolution, no offline queue |
| **No data migration path** | **High** | Existing local SQLite data cannot be migrated to cloud |
| **No backup/restore** | **High** | Users lose all data on app uninstall or device loss |

### 4.3 Security ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No secure storage** | **Critical** | Sensitive data (API keys, tokens) in SharedPreferences or `.env` |
| **No encryption at rest** | **High** | SQLite database unencrypted |
| **No network security** | **High** | No certificate pinning, no API request signing |
| **No audit logging** | **Medium** | No record of data access or modifications |

### 4.4 Platform & Infrastructure ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No Firebase project** | **Critical** | Not created; no google-services.json / GoogleService-Info.plist |
| **No CI/CD** | **High** | No GitHub Actions, no automated test/build/deploy |
| **No crash reporting** | **High** | No Firebase Crashlytics or Sentry |
| **No analytics** | **Medium** | No Firebase Analytics or custom events |
| **No remote config** | **Medium** | No feature flags or dynamic config |
| **iOS untested** | **Medium** | Development on Windows; no macOS/Xcode verification |

### 4.5 Data Quality & Compliance ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No data provenance** | **High** | Sample data marked "Sample data" but no audit trail |
| **No export (GDPR/CCPA)** | **High** | Privacy screen has "Download my data" button but it shows "not configured" |
| **No data retention policy** | **Medium** | No auto-expiry for old transactions/assessments |
| **No financial regulation awareness** | **Medium** | Disclaimer-only approach; no compliance framework |

### 4.6 Investment Intelligence Gaps ❌
| Gap | Severity | Description |
|-----|----------|-------------|
| **No live market data** | **High** | KASE/AIX APIs not integrated; all data user-entered |
| **No issuer disclosures** | **High** | Qualitative conditions always "Insufficient" without automated fetching |
| **No AI-powered analysis** | **Medium** | Rule-based only; AI assistant is chat-only, not thesis analysis |
| **No broker integration** | **Medium** | Auto-invest is illustrative only |

---

## 5. Firebase Migration Architecture

### 5.1 Target Architecture
```
┌─────────────────────────────────────────────────────────────────────┐
│                         SmartSave Production                        │
├─────────────────────────────────────────────────────────────────────┤
│  Client (Flutter)                                                   │
│  ├── Firebase Auth (Email/Password + OAuth: Google, Apple)         │
│  ├── Cloud Firestore (Authoritative cloud data)                    │
│  ├── Firebase Storage (Receipts, exports, avatars)                 │
│  ├── Firebase Functions (Backend logic, webhooks, scheduled jobs)  │
│  ├── Firebase Crashlytics (Crash reporting)                        │
│  ├── Firebase Analytics (Event tracking)                           │
│  ├── Firebase Remote Config (Feature flags, rate configs)          │
│  └── Firebase Messaging (Push notifications)                       │
├─────────────────────────────────────────────────────────────────────┤
│  Local Persistence (Offline-First)                                  │
│  ├── SQLite (sqflite) — Local cache & offline writes               │
│  ├── Secure Storage (flutter_secure_storage) — Tokens, secrets     │
│  └── SharedPreferences — Non-sensitive UI preferences              │
├─────────────────────────────────────────────────────────────────────┤
│  Synchronization Service                                            │
│  ├── Upload Queue (Pending local → cloud)                          │
│  ├── Download Stream (Cloud → local via Firestore listeners)       │
│  ├── Conflict Resolution (Last-write-wins + field-level merge)     │
│  ├── Retry Logic (Exponential backoff, dead letter queue)          │
│  └── Sync Status UI (Pending, Synced, Conflict indicators)         │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Firestore Data Model

#### Collections Structure
```
/users/{userId}                    — User profile document
/users/{userId}/transactions/{txnId}
    - amount: number (integer tenge)
    - isIncome: boolean
    - category: string
    - merchant: string
    - occurredAt: Timestamp
    - note: string
    - source: string ('Manual entry' | 'Bank sync' | 'AI categorization')
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string (SQLite row ID for correlation)

/users/{userId}/goals/{goalId}
    - name: string
    - target: number
    - saved: number
    - deadline: Timestamp
    - purpose: string
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/goals/{goalId}/contributions/{contribId}
    - amount: number
    - contributedAt: Timestamp
    - note: string
    - createdAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/budgets/{category}
    - monthlyLimit: number
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null

/users/{userId}/investmentTheses/{thesisId}
    - securityName: string
    - ticker: string
    - exchange: string
    - identifier: string
    - rationale: string
    - horizon: string
    - assumptions: string
    - risks: string
    - invalidationConditions: string
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/investmentTheses/{thesisId}/conditions/{conditionId}
    - description: string
    - metric: string
    - comparator: 'atLeast' | 'atMost'
    - threshold: number | null
    - observedValue: number | null
    - reportingPeriod: string
    - source: string
    - evidenceNote: string
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/investmentTheses/{thesisId}/assessments/{assessmentId}
    - assessedAt: Timestamp
    - conditions: array<ConditionAssessment>
    - supportingArguments: array<string>
    - counterarguments: array<string>
    - unverifiedAssumptions: array<string>
    - overlookedRisks: array<string>
    - reconsiderationTriggers: array<string>
    - additionalInformation: array<string>
    - createdAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/portfolioHoldings/{holdingId}
    - securityName: string
    - ticker: string
    - exchange: string
    - identifier: string
    - marketValueKzt: number
    - fxSensitivityPctPerPct: number | null
    - oilSensitivityPctPerPct: number | null
    - rateSensitivityPctPerPoint: number | null
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - syncedAt: Timestamp | null
    - localId: string

/users/{userId}/investmentSettings/{key}
    - value: string
    - updatedAt: Timestamp

/users/{userId}/depositProducts/{productId}  (optional: cached reference data)
    - bank: string
    - product: string
    - termMonths: number
    - effectiveRateBps: number
    - nominalRateBps: number
    - topUp: boolean
    - withdrawal: boolean
    - capitalization: boolean
    - source: string
    - cachedAt: Timestamp

/users/{userId}/advice/{adviceId}
    - kind: string
    - title: string
    - body: string
    - source: string
    - status: string
    - createdAt: Timestamp

/users/{userId}/watchlist/{ticker}
    - addedAt: Timestamp

/users/{userId}/aiMessages/{messageId}
    - role: 'user' | 'assistant' | 'system'
    - content: string
    - timestamp: Timestamp
    - isStreaming: boolean
    - error: string | null

/users/{userId}/syncMetadata
    - lastFullSync: Timestamp
    - pendingUploadCount: number
    - lastConflictAt: Timestamp | null
    - schemaVersion: number
```

### 5.3 Firestore Security Rules (Draft)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public reference data (deposit products) — read-only for authenticated users
    match /referenceData/depositProducts/{productId} {
      allow read: if request.auth != null;
    }
  }
}
```

---

## 6. Authentication Design

### 6.1 Firebase Auth Providers
| Provider | Priority | Notes |
|----------|----------|-------|
| Email/Password | **P0** | Primary; enforce strong password policy |
| Google Sign-In | **P0** | Android/iOS/Web; one-tap on Android |
| Apple Sign-In | **P1** | Required for iOS App Store |
| Anonymous Auth | **P2** | For trial/guest mode; link later |

### 6.2 Auth Flow
```
1. Welcome Screen
   ├── New User → Email/Password Sign Up → Email Verification → Onboarding
   ├── Existing User → Email/Password Sign In → Home
   ├── Google Sign In → (Auto-create or link) → Onboarding/Home
   └── Apple Sign In → (Auto-create or link) → Onboarding/Home

2. Onboarding (Post-auth)
   ├── Step 1: Track (permissions, intro)
   ├── Step 2: Save (goal creation)
   ├── Step 3: Grow (risk quiz, investment intro)
   └── Complete → AppShell

3. Session Management
   ├── AuthStateChanges listener → routes to Welcome or AppShell
   ├── Token auto-refresh (handled by Firebase SDK)
   ├── Secure storage for refresh tokens (flutter_secure_storage)
   └── Logout → clears local cache + signs out from Firebase
```

### 6.3 Migration from Demo Auth
| Current (Demo) | Target (Production) |
|----------------|---------------------|
| `demo_session` bool in SharedPreferences | Firebase Auth `currentUser` |
| `demo_contact` string | `user.email` + `user.displayName` |
| `risk_profile` string | Firestore `/users/{uid}/profile/riskProfile` |
| `quiz_answers` string | Firestore `/users/{uid}/profile/quizAnswers` |
| `onboarding_complete` bool | Firestore `/users/{uid}/profile/onboardingComplete` |

---

## 7. Synchronization Design

### 7.1 Sync Architecture
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Local SQLite   │◄───►│  Sync Service    │◄───►│  Cloud Firestore │
│   (Source of     │     │  (Riverpod       │     │  (Authoritative  │
│    truth offline)│     │   Background)    │     │   source online) │
└──────────────────┘     └──────────────────┘     └──────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
   Pending Writes           Conflict                  Real-time
   Queue (local)            Resolution               Listeners
```

### 7.2 Sync Strategies by Entity
| Entity | Strategy | Conflict Resolution |
|--------|----------|---------------------|
| **Transactions** | Append-only (immutable) | Server wins; local ID mapped to server ID |
| **Goals** | Last-write-wins + merge contributions | Merge: server goal + local contributions not on server |
| **Goal Contributions** | Append-only | Server wins; deduplicate by (goalId, amount, date) |
| **Budgets** | Last-write-wins | Server wins (user edits on one device at a time) |
| **Investment Theses** | Last-write-wins | Server wins; preserve assessment history |
| **Thesis Conditions** | Last-write-wins | Server wins |
| **Thesis Assessments** | Append-only (immutable history) | Server wins; merge by assessedAt |
| **Portfolio Holdings** | Last-write-wins | Server wins |
| **Investment Settings** | Last-write-wins | Server wins |
| **Preferences** | Last-write-wins per key | Server wins |

### 7.3 Offline Queue Implementation
```dart
// Local pending writes table (SQLite)
CREATE TABLE pending_writes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collection TEXT NOT NULL,           // e.g., 'transactions', 'goals'
  documentId TEXT,                    // Firestore doc ID (null for creates)
  localId TEXT NOT NULL,              // SQLite row ID for correlation
  operation TEXT NOT NULL,            // 'create' | 'update' | 'delete'
  payload TEXT NOT NULL,              // JSON of document data
  createdAt TEXT NOT NULL,            // ISO8601
  retryCount INTEGER DEFAULT 0,
  lastError TEXT,
  status TEXT DEFAULT 'pending'       // 'pending' | 'syncing' | 'failed' | 'synced'
);
```

### 7.4 Sync Service Responsibilities
1. **Upload**: Process pending_writes queue → Firestore batch writes
2. **Download**: Firestore real-time listeners → local SQLite upserts
3. **Conflict Detection**: Compare `updatedAt` / `syncedAt` timestamps
4. **Retry Logic**: Exponential backoff (1s, 2s, 4s, 8s, max 5min); max 5 retries
5. **Dead Letter**: After max retries → move to `sync_failures` table for manual review
6. **Status UI**: Stream sync state to UI (pending count, last sync time, conflicts)

---

## 8. Data Migration Strategy

### 8.1 Migration Principles
- **One-time migration** on first login after update
- **Preserve all local data** — no data loss
- **Idempotent** — safe to retry
- **User-visible progress** — show migration status
- **Rollback plan** — keep local SQLite until migration verified

### 8.2 Migration Steps
```
1. User updates app → launches → sees "Migrating your data..." screen
2. Check if migration already completed (SharedPreferences flag)
3. If not migrated:
   a. Authenticate user (Firebase Auth)
   b. Read ALL local SQLite tables
   c. For each entity:
      i. Transform local model → Firestore document
      ii. Write to Firestore (batch, 500 ops max)
      iii. On success: record Firestore docId in local mapping table
   d. Verify counts match (local vs cloud)
   e. Mark migration complete in SharedPreferences
   f. Enable sync service
4. User sees "Migration complete!" → enters app
```

### 8.3 Entity-Specific Migration Logic

| Entity | Migration Logic |
|--------|-----------------|
| **Transactions** | Insert all; use `localId` = SQLite `id`; `syncedAt` = now |
| **Goals** | Insert goals; then insert contributions with `goalId` = Firestore goal docId |
| **Budgets** | Upsert by category (category = docId) |
| **Investment Theses** | Insert; then conditions (subcollection); then assessments (subcollection) |
| **Portfolio Holdings** | Insert all |
| **Investment Settings** | Upsert by key |
| **Watchlist** | Insert ticker docs |
| **Advice History** | Insert all (read-only reference) |
| **AI Messages** | Insert last 100 messages only (trim history) |

### 8.4 Handling Demo/Seed Data
- **Tag all seeded records** with `source: 'Sample data'` or `source: 'Demo seed'`
- **User option**: "Keep sample data" vs "Start fresh"
- **If fresh**: Delete all `source: 'Sample data'` records before migration
- **If keep**: Migrate as-is; user can delete later

### 8.5 Migration Verification
```dart
// After migration, verify:
assert(await localTransactionCount() == await cloudTransactionCount());
assert(await localGoalsCount() == await cloudGoalsCount());
// ... for all entities
// Log discrepancies for debugging
```

---

## 9. Security Requirements

### 9.1 Data Protection
| Requirement | Implementation |
|-------------|----------------|
| **Encryption at rest (local)** | Use `sqlcipher` or `sqflite` with encryption extension; key from `flutter_secure_storage` |
| **Encryption in transit** | Firebase handles TLS 1.2+; enforce in `network_security_config.xml` (Android) |
| **Secure token storage** | `flutter_secure_storage` for Firebase auth tokens, API keys |
| **API key protection** | Backend `.env` never committed; use Firebase Functions for OpenRouter proxy in production |
| **Certificate pinning** | Optional: `dio` with `HttpClientBadCertificateCallback` for API calls |

### 9.2 Access Control
| Requirement | Implementation |
|-------------|----------------|
| **Per-user data isolation** | Firestore security rules: `request.auth.uid == resource.data.userId` |
| **Admin access** | Custom claims (`admin: true`) for support team |
| **Rate limiting** | Firebase Functions + App Check for API abuse prevention |

### 9.3 Compliance
| Requirement | Implementation |
|-------------|----------------|
| **GDPR/CCPA Export** | Cloud Function: aggregate all user collections → JSON → signed Storage URL |
| **Right to deletion** | Cloud Function: cascade delete user data + Auth account |
| **Data retention** | TTL policies on Firestore (e.g., AI messages 90 days); scheduled Cloud Function cleanup |
| **Audit logging** | Firebase Audit Logs + custom `auditLogs` collection for sensitive operations |

---

## 10. Testing Strategy

### 10.1 Test Pyramid
```
                    ┌─────────────┐
                    │   E2E (5)   │  ← Critical flows: auth, sync, migration
                   ┌┴─────────────┴┐
                  │ Integration (15)│  ← Repository + sync service, Firestore rules
                 ┌┴─────────────────┴┐
                │   Widget (25)      │  ← Screens, forms, navigation
               ┌┴────────────────────┴┐
              │    Unit (50+)        │  ← Models, math, analysis, repo logic
             └────────────────────────┘
```

### 10.2 Test Coverage Targets
| Layer | Target | Current |
|-------|--------|---------|
| Unit | ≥90% | ~70% (finance_repo, investment_intelligence, financial_math) |
| Widget | ≥80% | ~40% (some screen tests) |
| Integration | ≥70% | 0% (no sync/Firestore tests yet) |
| E2E | ≥5 critical paths | 0% (no device farm) |

### 10.3 New Test Requirements
| Test Type | Scenarios |
|-----------|-----------|
| **Unit** | Sync queue processing, conflict resolution, migration transformers |
| **Integration** | Auth → Firestore write → read; Offline → online sync; Migration dry-run |
| **Widget** | Auth screens, sync status indicators, conflict resolution UI |
| **E2E** | New user signup → onboarding → create goal → offline edit → online sync; Existing user login → migration → verify data |

### 10.4 CI/CD Pipeline (GitHub Actions)
```yaml
# .github/workflows/ci.yml
on: [push, pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps: [checkout, flutter setup, flutter pub get, flutter analyze]
  test:
    runs-on: ubuntu-latest
    steps: [checkout, flutter setup, flutter pub get, flutter test --coverage]
  build-android:
    runs-on: ubuntu-latest
    needs: [analyze, test]
    steps: [checkout, flutter setup, flutter build apk --release]
  build-ios:
    runs-on: macos-latest
    needs: [analyze, test]
    steps: [checkout, flutter setup, flutter build ios --release --no-codesign]
```

---

## 11. Ordered Implementation Stages

### Stage 0: Foundation (Days 1-3) ✅ **COMPLETE — This Audit**
- [x] Full codebase audit
- [x] Git repository initialization
- [x] Documentation of current state

### Stage 1: Git & Firebase Setup (Days 4-6)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Initialize Git repo, commit all files | 2h | — |
| Create GitHub repository, push | 1h | Git commit |
| Create Firebase project (prod + staging) | 2h | — |
| Configure Android (google-services.json) | 1h | Firebase project |
| Configure iOS (GoogleService-Info.plist) | 1h | Firebase project + macOS |
| Add FlutterFire CLI, configure `firebase_options.dart` | 2h | Firebase project |
| Enable Auth (Email/Password, Google, Apple) | 1h | Firebase console |
| Create Firestore database (production mode) | 1h | Firebase console |
| Deploy security rules (draft) | 1h | Firestore schema |
| Set up GitHub Actions CI (analyze, test, build) | 4h | GitHub repo |

### Stage 2: Authentication Migration (Days 7-10)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Add `firebase_auth`, `flutter_secure_storage` dependencies | 1h | Stage 1 |
| Implement AuthService (signIn, signUp, signOut, authStateChanges) | 4h | Dependencies |
| Replace demo auth screens with Firebase Auth screens | 8h | AuthService |
| Migrate `demo_session` → Firebase Auth state | 2h | AuthService |
| Migrate profile data (name, email) → Firestore `/users/{uid}/profile` | 4h | Firestore |
| Implement email verification flow | 3h | Auth |
| Implement password reset flow | 2h | Auth |
| Add Google Sign-In (Android/iOS) | 4h | Platform config |
| Add Apple Sign-In (iOS) | 3h | macOS + Apple Developer |
| Test auth flows on Android + iOS | 4h | Devices/simulators |

### Stage 3: Firestore Schema & Repository Abstraction (Days 11-14)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Define Firestore data models (Dart classes with `fromMap`/`toMap`) | 4h | Stage 2 |
| Create `FirestoreRepository` interface (mirrors `FinanceRepository`) | 6h | Models |
| Implement FirestoreRepository with batch writes, listeners | 12h | Firestore SDK |
| Add `syncedAt`, `localId` fields to all models | 2h | Models |
| Implement repository factory (local vs cloud based on auth state) | 3h | Both repos |
| Unit test FirestoreRepository (emulator) | 4h | Firestore emulator |

### Stage 4: Synchronization Service (Days 15-19)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Create `pending_writes` SQLite table | 2h | Stage 3 |
| Implement `SyncService` (Riverpod Notifier) | 8h | FirestoreRepository |
| Upload queue processor (batched writes, retry logic) | 6h | SyncService |
| Download listeners (real-time Firestore → local SQLite) | 6h | SyncService |
| Conflict detection & resolution (LWW + field merge) | 6h | SyncService |
| Sync status UI (pending badge, last sync time, conflict alerts) | 4h | SyncService |
| Offline indicator + "Sync now" button | 2h | SyncService |
| Integration tests (offline → online scenarios) | 6h | Emulator + device |

### Stage 5: Data Migration (Days 20-22)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Create migration service (one-time on first auth) | 6h | Stage 4 |
| Implement entity transformers (local → Firestore) | 6h | Models |
| Add migration progress screen with cancel option | 3h | MigrationService |
| Handle demo data (tag, option to keep/discard) | 2h | MigrationService |
| Verification & rollback logic | 3h | MigrationService |
| Test migration with seeded demo data | 4h | Device |

### Stage 6: Security Hardening (Days 23-26)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Encrypt local SQLite (sqlcipher) | 4h | Stage 5 |
| Move API keys to Firebase Functions (OpenRouter proxy) | 4h | Firebase Functions |
| Implement secure storage for tokens | 2h | flutter_secure_storage |
| Add network security config (Android) | 2h | — |
| Audit Firestore rules for least privilege | 2h | Stage 3 |
| Add App Check (Play Integrity / DeviceCheck) | 3h | Firebase console |

### Stage 7: Production Features (Days 27-33)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Crashlytics integration | 2h | Firebase |
| Analytics events (key user actions) | 3h | Firebase Analytics |
| Push notifications (FCM) for goal reminders, budget alerts | 6h | FCM + SyncService |
| Remote Config (feature flags, deposit rates source) | 3h | Remote Config |
| GDPR/CCPA export Cloud Function | 4h | Firebase Functions |
| Account deletion Cloud Function (cascade) | 3h | Firebase Functions |

### Stage 8: Testing & Polish (Days 34-40)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| E2E tests on Firebase Test Lab (Android + iOS) | 8h | Stage 7 |
| Performance profiling (startup, sync, large datasets) | 4h | Device |
| Accessibility audit (TalkBack, VoiceOver) | 4h | Device |
| Security review (penetration test light) | 4h | — |
| Beta release to internal testers (TestFlight/Play Console) | 4h | Builds |
| Bug fixes from beta feedback | 8h | — |

### Stage 9: Launch Preparation (Days 41-44)
| Task | Estimate | Dependencies |
|------|----------|--------------|
| Production Firebase project final config | 2h | — |
| App Store / Play Store listings, screenshots | 4h | — |
| Privacy policy, terms of service (legal review) | 4h | Legal |
| Release build + upload | 4h | CI/CD |
| Staged rollout (10% → 50% → 100%) | 2h | Play Console / App Store Connect |
| Monitoring dashboard (Crashlytics, Analytics, Sync health) | 2h | Firebase |

---

## 12. Estimated Complexity & Blockers

### 12.1 Complexity Assessment

| Stage | Complexity | Risk Level | Notes |
|-------|------------|------------|-------|
| Stage 1: Git & Firebase Setup | **Low** | Low | Standard setup; well-documented |
| Stage 2: Auth Migration | **Medium** | Medium | Platform-specific config (iOS Apple Sign-In needs macOS) |
| Stage 3: Firestore Repository | **Medium-High** | Medium | Dual-repo abstraction; must not break existing UI |
| Stage 4: Sync Service | **High** | **High** | Core complexity: conflict resolution, offline queue, real-time listeners |
| Stage 5: Data Migration | **Medium-High** | **High** | One-shot; must be idempotent; data loss unacceptable |
| Stage 6: Security | **Medium** | Medium | SQLCipher setup can be finicky on Windows |
| Stage 7: Production Features | **Low-Medium** | Low | Standard Firebase integrations |
| Stage 8: Testing | **Medium** | Medium | Requires device farm; iOS testing needs macOS |
| Stage 9: Launch | **Low** | Low | Process-driven |

### 12.2 Critical Blockers & Mitigations

| Blocker | Impact | Mitigation |
|---------|--------|------------|
| **iOS development on Windows** | Cannot build/test iOS locally | Use GitHub Actions macOS runners; borrow Mac for final verification; Firebase Test Lab for iOS |
| **Sync service complexity** | Highest technical risk; could delay entire project | Start Stage 4 early; use Firestore emulator extensively; consider simpler LWW-only first, add field-merge later |
| **Data migration risk** | Irreversible data loss if bugs | Dry-run migration on copy of local DB; extensive logging; user-visible progress; rollback to local-only mode |
| **Firebase Free Tier limits** | Spark plan: 50K reads/day, 20K writes/day | Monitor usage; batch writes; cache aggressively; upgrade to Blaze before launch |
| **SQLCipher on Windows** | Compilation issues with native extensions | Test early; fallback: use `flutter_secure_storage` for key + application-level encryption for sensitive fields only |
| **No Technical Requirements Spec** | Scope ambiguity | This audit serves as baseline; confirm priorities with team |

### 12.3 Timeline Summary

```
Total Estimated Effort: ~200-250 hours
Calendar Days (1 dev, 6h/day): ~35-42 days
Calendar Days (2 devs, parallel): ~20-25 days

DEADLINE: December 10, 2026 (22 days from Nov 18)

REALISTIC ASSESSMENT:
- With 1 developer: HIGH RISK of missing deadline
- With 2 developers (parallel Stages 3+4, 5+6): MODERATE RISK
- Recommended: Prioritize Stages 1-5 (core sync); defer Stages 6-7 to post-launch if needed
```

### 12.4 Minimum Viable Production (MVP for Launch)
If deadline pressure requires scope reduction, **launch with**:
1. ✅ Firebase Auth (Email/Password + Google)
2. ✅ Firestore for all entities (no sync service yet — **online-only**)
3. ✅ One-time migration on first login
4. ✅ Basic security rules
5. ✅ Crashlytics

**Defer to post-launch**:
- Offline sync service (Stage 4)
- Full security hardening (Stage 6)
- Push notifications, Remote Config (Stage 7)
- GDPR export, account deletion functions (Stage 7)

---

## 13. Recommended Next Implementation Stage

### **Stage 1: Git & Firebase Setup** (Days 4-6)
**Priority**: **IMMEDIATE** — Unblocks all subsequent work

**Exact Steps**:
1. `git add . && git commit -m "Initial commit: SmartSave v6 local MVP"`
2. Create GitHub repository `smartsave-v6` (private)
3. `git remote add origin https://github.com/<org>/smartsave-v6.git && git push -u origin master`
4. Create Firebase project `smartsave-prod` (and `smartsave-staging`)
5. Enable Authentication → Email/Password, Google, Apple
6. Create Firestore database (Native mode, production)
7. Download `google-services.json` → `android/app/`
8. Download `GoogleService-Info.plist` → `ios/Runner/` (requires macOS)
9. Run `dart pub global activate flutterfire_cli && flutterfire configure`
10. Add GitHub Actions workflow for `flutter analyze`, `flutter test`, `flutter build apk`

**Estimated Time**: 8-12 hours  
**Blocker**: iOS config requires macOS — can do Android first, iOS in parallel on macOS runner

---

## Appendix A: File Inventory (Key Files)

```
lib/
├── main.dart                          # App entry, DI setup
├── data/
│   ├── finance_repository.dart        # SQLite schema + ALL CRUD (1000+ lines)
│   ├── finance_controller.dart        # Riverpod ChangeNotifier
│   ├── providers.dart                 # Riverpod providers
│   ├── investment_models.dart         # Thesis, Condition, Assessment, Holding
│   ├── financial_math.dart            # Interest, goal calculations
│   └── investment_analysis.dart       # Liquidity, ripple calculations
├── features/
│   ├── app/
│   │   ├── app.dart                   # Auth, onboarding, AppShell
│   │   └── demo_flow_screens.dart     # ConnectCard, RiskQuiz, RiskProfile
│   ├── transactions/transactions_screen.dart
│   ├── goals/goals_screen.dart
│   ├── invest/
│   │   ├── invest_hub_screen.dart
│   │   ├── investment_intelligence_screen.dart  # 2000+ lines
│   │   ├── invest_screen.dart
│   │   └── stocks_screen.dart
│   ├── profile/
│   │   ├── profile_screen.dart        # Settings, privacy, delete
│   │   └── my_account_screen.dart
│   └── advice/                        # AI assistant screens
├── ai/
│   ├── ai_assistant_service.dart      # OpenRouter streaming + fallback
│   ├── openrouter_provider.dart
│   ├── models.dart
│   └── config.dart
└── shared/
    ├── theme.dart                     # ColorScheme, TextTheme
    └── widgets.dart                   # Reusable UI components

backend/
├── server.js                          # Express OpenRouter proxy (free-tier only)
├── package.json
└── .env                               # OPENROUTER_API_KEY (gitignored)

test/
├── finance_repository_test.dart
├── investment_intelligence_test.dart
├── financial_assistant_service_test.dart
├── financial_assistant_screen_test.dart
├── assistant_bubble_widget_test.dart
├── widget_test.dart
├── app_flow_test.dart
└── investment_intelligence_widget_test.dart

docs/
├── project-overview.md
├── investment-intelligence.md
├── figma-audit.md
├── demo-script.md
└── SMARTSAVE_AI_DEMO_GUIDE.md
```

---

## Appendix B: SQLite Schema Reference

```sql
-- Core financial tables (created in onCreate v1)
CREATE TABLE transactions (...);
CREATE TABLE goals (...);
CREATE TABLE goal_contributions (...);
CREATE TABLE budgets (...);
CREATE TABLE preferences (...);
CREATE TABLE advice (...);
CREATE TABLE watchlist (...);
CREATE TABLE deposit_products (...);

-- Investment tables (added in onUpgrade v2)
CREATE TABLE investment_theses (...);
CREATE TABLE thesis_conditions (...);
CREATE TABLE thesis_assessments (...);
CREATE TABLE portfolio_holdings (...);
CREATE TABLE investment_settings (...);

-- AI messages (added in onUpgrade v3)
CREATE TABLE ai_messages (...);

-- Unused migration functions (defined but not in current schema version)
_createInvestmentAllocationsTable
_createCashAccountsTable
```

---

*End of Audit Document*  
*Generated: 2026-11-18*  
*Next Review: After Stage 1 completion*