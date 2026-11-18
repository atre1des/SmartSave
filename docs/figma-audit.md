# SmartSave Figma audit and MVP plan

**Source:** [SmartSave — Key Screens](https://www.figma.com/design/B1IgCz1Vha2ikNryzEtB3j/SmartSave-%E2%80%94-Key-Screens--UI---Copy-?node-id=0-1)  
**Inspected:** 16 October 2026. The file exposes one page (`Key Screens`) with 40 top-level frames: 39 product screens/states and one visual-token board. Each product frame is 390 × 844 px. The Figma Plugin API exposed 217 prototype action links, which were inspected; these identify intended navigation but do not prove runtime behavior.

## 1. Screen inventory and purpose

| Frame | Purpose / evidence in the design |
|---|---|
| 01 Splash / Welcome | SmartSave brand, tagline, Get started and existing-account entry points. |
| 02 Sign up | Email/phone, password, confirmation, terms consent, create account. |
| 03 Log in | Email/phone, password, Sign in and Forgot password. |
| 04 Onboarding (1 of 3) | Spending-category explainer, Skip and Next. Only step 1 is present; steps 2 and 3 are absent. |
| 05 Connect card | Bank choice, card field, read-only data-consent claims, manual-entry skip. No real bank integration is evidenced. |
| 14 Connection failed (state) | Connection failure reasons, retry and skip-for-now. |
| 02 Risk quiz | Question 2 of 5, risk choices, rationale and Next. Only one quiz question screen is present. |
| 10 Risk profile | Moderate risk result, explanations, illustrative asset mix, retake/edit actions and disclaimer. |
| 03 Overview | Total balance, monthly spending, linked-card indicator, goal progress, advice of the day, top-spending categories and recent transactions. |
| 04 Categories & analytics | Monthly spending donut and category shares, prior-month comparisons, budget-overrun notice and “Where to cut” link. |
| 05 Savings plan | Goal target/deadline, monthly contribution affordability, projected savings schedule and suggested cuts; Save goal / Adjust. |
| 06 Rate table | Tenge deposit products, maturity/filter chips, bank rates, nominal rates, source/update note and comparison entry. |
| 07 Deposit details | Deposit terms, amount/income estimator, rationale, link-to-goal, bank handoff and comparison. |
| 08 Stock watchlist | Risk-profile-aware KASE stock sample rows, Picks/Watchlist selector, risk-fit indicators and disclaimer. |
| 09 Stock details | Stock quote sample, time-range selector/chart, risk-fit explanation, watchlist action and disclaimer. |
| 15 Transactions | Search, category filters, date groups, imported/manual examples and add action. |
| 16 Transaction details | Amount, merchant, category, date, source, note, recurrence indicator and save-changes action. |
| 17 Add transaction | Expense/income selector, amount, category, date, optional note and Save. |
| 18 Category details (Food) | Month-to-date category spending, budget comparison/overrun, top merchants, recurring-spend insight and cut-spending link. |
| 19 My goals | Free-cash summary, goal progress/status rows and New goal. |
| 20 Create / edit goal | Goal name, target amount, deadline, purpose selection and savings-plan action. |
| 21 Goal progress | Saved/remaining/monthly figures, reminder, milestones, coming-later auto-save, add money and edit goal. |
| 22 Where to cut | Spending-based savings suggestions, estimated monthly room, projected goal date, apply-selected and dismiss actions. |
| 23 Auto-save (later) | Explicit Coming later screen describing a future automatic transfer; notify action. Do not simulate actual money movement. |
| 24 Filters & comparison | Deposit term/features filters, side-by-side three-bank comparison and Apply filters. |
| 25 Calculator | Deposit amount/term/product inputs, estimated interest and comparison, disclaimer and link-to-goal. |
| 26 Why this deposit? | Recommendation reasons, checks, sources, update date and financial-information disclaimer. |
| 27 No results (state) | Empty deposit-filter result with reset/remove-filter actions. |
| 28 Recommendations | Sample stock/deposit/cash-cushion cards with reasons, sources and not-advice disclaimer. |
| 29 Bonds & auto-invest (later) | Explicit future module; explains regulated brokerage dependency and notify action. |
| 30 Profile & Settings | Profile entry, connected accounts, notifications, advice history, privacy/data, subscription, help and log out. |
| 31 Profile | Name, contact, country, currency, language and save. |
| 32 Connected accounts | Read-only card status, last sync, disconnect/sync/add-card actions and limitation copy. |
| 33 Notifications | Goal, budget, advice, deposit-rate and market-notification preferences. |
| 34 Advice history | Type filters and dated savings/deposit/stock advice with applied/viewed/saved status. |
| 35 Privacy & data | Personal-advice and anonymous-stat consents, data-use explanation, download-data and delete-account actions. |
| 36 Delete account (confirm) | Password confirmation, consequences, permanent delete and cancel. |
| 37 Subscription | Free/Premium feature lists, “price to be set” and explicitly demo Premium action. |
| 38 Help & support | Help search, FAQ accordion, support chat and privacy-policy action. |

The separate **Design tokens** frame is not a product screen. The file has no published/local component nodes; repeated UI is composed from named frames/groups within screens.

## 2. Navigation and interaction evidence

Prototype reactions were available and yielded 217 action links. Confirmed destinations include:

- Welcome → Sign up or Log in; both account forms → onboarding step 1. Signup/login tab switch, back-to-welcome and forgot-password are represented; no forgot-password destination is supplied.
- Onboarding step 1 → Connect card (Next or Skip). Connect-card skip and connection-failure skip → Risk quiz. Retry returns to Connect card. Connect-card primary action enters Risk quiz; no real bank authorization path/API is specified.
- Risk quiz → Risk profile; risk profile can retake the quiz. The quiz is labelled 2 of 5 but only one question frame is provided; quiz completion and other questions are missing.
- Bottom navigation destinations are Home/Overview, Goals/My goals, Deposits/Rate table, Invest/Stock watchlist and Profile/Profile & Settings. The five-tab bar is reused on most signed-in screens.
- Overview → goal progress, spending analytics, transaction list and cut-spending advice. Analytics → category detail and cut-spending. Goal list → goal progress or create/edit; goal editor → savings plan; goal progress → editor or coming-later auto-save; cut-spending → savings plan (apply or dismiss).
- Rate table → deposit details, filters/comparison and no-results state. Deposit details → calculator, rationale, savings-plan link and comparison; calculator links to goal; comparison applies back to the rate table; no-results actions reset filters.
- Watchlist → stock detail; stock detail → watchlist/recommendations. “Coming later” bonds/auto-invest links back to the watchlist.
- Transactions → transaction detail and add transaction. Details/editor save back to the list. Profile settings open profile, connected accounts, notifications, advice history, privacy, subscription and help; logout returns to Welcome. Privacy opens delete confirmation; permanent delete returns to Welcome; cancel returns to privacy. Connected accounts can open Add card.

Not every visible control has a prototype reaction, and links are not a full product specification. Any destination missing from the prototype or any unlinked visible control needs a functional, conservative outcome consistent with the screen (e.g. validation, local-state update, confirmation, or an explicitly disabled/Coming later state).

## 3. Visual system and reusable patterns

- **Typeface:** Inter. **Canvas/background:** `#F4FAF6`. **Primary/text/button:** Firefly `#032C30`. **Secondary chart/info:** Prussian Blue `#032B52`. **Accent/progress:** Mint `#8FD1B1`; **pale card/chip:** Mint Light `#DDF1E6`; **highlight/best rate:** Old Gold `#CBAF2B`; **positive change:** Lime `#C3D96E`; **warning/high risk:** Wine `#8B2E3C`.
- Type ramp documented in the token board: H1 24 bold, H2 16 semibold, body 14 regular, caption 11 regular. Cards have 16 px radius; primary buttons are 52 px high with pill-like corners. Dark text on mint and white text on Firefly are intentional contrast choices; gold is a single focal highlight.
- Repeated structures: five-item tab bar, status/battery strip, back control, pill buttons, text/amount fields, segmented selectors, chips, bank/transaction/goal rows, progress bars, cards, empty/error states, disclaimers and bottom-aligned actions.
- No separate variable collections or reusable component nodes were exposed. The named Design tokens board provides the observed palette/type/shape rules. Figma image/SVG assets are used in the welcome artwork/logo; implementation must use downloaded local assets, never temporary Figma URLs.

## 4. Forms, data and calculations implied

- **Account/onboarding:** contact (email or phone), password/confirmation, terms/data consents, bank selection/card flow, risk answers, profile country/currency/language.
- **Transactions:** amount in KZT, income/expense type, category (Food, Transport, Shopping, Bills, Health, Other), date, merchant/description, optional note, source/import status, recurrence. Search and category filters are shown.
- **Goals:** name, target amount, deadline, purpose, contribution schedule/reminder, current saved amount, add-money contribution and progress/milestones.
- **Budgets/analytics:** category/month budget (Food example: 95,000 ₸), monthly category totals/shares and comparisons; over-budget amount; month-to-month changes; top merchants and recurring spend.
- **Dashboard:** total balance and current-month spend, computed category totals, goal progress, recent transactions and advice. Figures must be derived from persisted demo/user records, not independent hard-coded totals.
- **Deposits:** sample/local bank-rate catalogue with currency, term, effective and nominal rates, top-up/withdrawal/capitalization filters, source/update date, compare list. Interest estimate (example: 1,000,000 ₸ for 3 months at nominal 17.91% gives approximately 44,800 ₸) must be labelled estimate and its calculation assumptions documented.
- **Investments/advice:** sample stock quotes, time ranges, risk fit/profile/illustrative mix and recommendations; no brokerage/purchase support. Advice should be transparently demo/sample content and carry the screen’s not-financial-advice disclaimer.

## 5. Unknowns, missing states and conservative decisions

1. Onboarding steps 2–3 and risk questions 1, 3–5 are not in the file. Implement the supplied step/question as evidence; for a complete journey, create missing steps in the same visual system and clearly label the copy as completion work, not inspected Figma content.
2. There is no real authentication service, bank-link provider, sync protocol, card authorization, financial data feed, stock quote feed, brokerage or subscription price. Use explicitly disclosed local demo auth, fictional/local seeded data, and simulated read-only connection states only. Never claim a card is connected to a bank or money was moved.
3. Some screens show imported transactions and a linked Kaspi balance, but no import or sync API is specified. Seed fictional example records and let users add/edit/delete local entries.
4. Budget editing/creation is implied by category budget messaging but has no dedicated budget editor. Provide an in-scope local budget edit control/flow consistent with category detail and mark it as a practical completion of a missing transition.
5. Data relationships for deposit yields, effective annual rates, rate freshness, recurrence detection, free cash, “reach a goal one month earlier,” recommendation status and risk allocation are not specified. Make algorithms explicit, deterministic, testable and label estimates/sample data.
6. The transaction details design says “Imported from bank” while MVP storage is local. Label seeded rows as sample/import-style records and user-added rows as manual to avoid implying a live connection.
7. Forgot password, policy links, change photo, support chat, download-data, notification scheduling and premium purchase have no backed service. Provide local demo behavior or non-destructive informational/Coming later affordances; do not claim external completion.
8. A permanent-delete screen exists. In demo mode, require confirmation and clear only local SmartSave data; explain that no bank/card account is actually disconnected.

## 6. Proposed end-to-end user journey

Welcome → demo sign-up/log-in → three-step onboarding (one evidenced step plus two clearly documented completion screens) → optional simulated card connection or manual-entry skip → five-question demo risk quiz (one evidenced question plus four documented completion questions) → risk profile → Overview. From Overview, the user can inspect category analytics, create/update a budget, add/edit/delete transactions, create a goal, record a contribution, inspect savings progress and deposit/investment recommendations, then manage preferences or log out. All signed-in primary tabs remain reachable through the repeated tab bar. This represents intended Figma navigation; local demo behavior replaces unsupported integrations.

## 7. MVP feature set (all Figma key screens retained)

The implementation scope is **all 39 product frames**, not only the three initial transactional features. The principal end-to-end demonstrable feature groups are:

1. **Financial overview, transactions, budgets and analytics** — help the user understand spending and correct records; create/search/filter/edit/delete transactions; configure category budgets; recalculate category and dashboard summaries. Acceptance: totals match stored transactions for the selected month/category, edits/deletes immediately update summaries, invalid/non-positive amounts are rejected, empty states work, persistence survives restart.
2. **Savings goals and planning** — define targets/deadlines/purpose, calculate progress/remaining/monthly amount, record contributions, edit goals and apply/dismiss spending-cut suggestions. Acceptance: remaining = max(target − contributions, 0), progress is bounded for display, contribution cannot be negative, edits and contribution history persist, projected plans state their assumptions.
3. **Deposit comparison/calculator and investment information views** — browse local sample catalog, filter/compare, inspect source/updated date, compute clearly labelled estimates, inspect sample stock/watchlist and rationale. Acceptance: filters yield matching products or the designed empty state; calculations use integer minor units/rational rate operations; source and not-advice disclosures appear; no purchasing or bank linking is represented as real.
4. **Account/onboarding, risk/profile and settings flows** — demo auth, onboarding, local risk quiz/profile, profile/settings, consent toggles, help, advice history, subscription demo, simulated connection failure, logout and local account-delete confirmation. Acceptance: every screen reachable as in the prototype where an edge exists, forms validate, destructive local reset requires explicit confirmation, unsupported services are identified as demo/Coming later.

## 8. Data model and persistence

Use local SQLite (sqflite) as the source of truth for structured data, plus SharedPreferences only for demo session/onboarding flags. Store money as integer minor units (tiyn) or exact integer tenge where design values are whole KZT; format only at the UI boundary. Proposed tables:

- `transactions(id, amount_minor, type, category_id, merchant, note, occurred_at, source, recurrence_key, created_at, updated_at)`
- `categories(id, name, icon_key, kind)`
- `budgets(id, category_id, period_month, limit_minor)`
- `goals(id, name, target_minor, deadline, purpose, reminder_day, created_at, updated_at)` and `goal_contributions(id, goal_id, amount_minor, contributed_at, note)`
- `risk_answers(id, question_index, answer_key)` and `user_profile(id, display_name, contact, country, currency, language, risk_level, consent_advice, consent_analytics)`
- `advice(id, type, title, body, source, status, created_at)`
- `deposit_products(id, bank, product, currency, term_months, effective_rate_bps, nominal_rate_bps, top_up, withdrawal, capitalization, source, updated_at)`; seed with marked fictional/sample catalogue data.
- Optional `watchlist(id, instrument_key, added_at)` and `notification_preferences(key, enabled)` where useful.

Use repositories to isolate SQL; use explicit transactions for goal contributions/account deletion; ship deterministic fictional seed data and a reset-demo-data action. No server, Firebase or third-party finance API.

## 9. Prioritized Flutter implementation plan

1. **Bootstrap/design foundation:** keep a clean Flutter 3/Dart app; define token constants, Inter (when licensed/supplied or use a documented system fallback), responsive 390 × 844-inspired layouts, shared cards/fields/buttons/chips/rows, and local Figma artwork assets. Riverpod for state; simple named-route or Navigator routing; sqflite repository and migrations.
2. **Runnable skeleton and state:** add app theme, boot/database initialization, session/onboarding flags, five-tab shell and reusable back/navigation behaviors. Verify it launches before feature work.
3. **Core local data and calculations:** define models/repositories/seed/reset; transaction, category/month budget, goal/contribution, dashboard aggregation and deposit estimator logic; unit tests first for currency and derived totals.
4. **Primary Figma journeys:** welcome/auth/onboarding/connect demo/risk flow; overview/analytics/category/budget; transactions/details/add; goals/editor/progress/planner/cut advice; rate table/details/filters/calculator/rationale/no results; watchlist/details/recommendations; profile/settings and all remaining frames/states. Keep each visible control actionable or honestly marked unavailable/later.
5. **Verification/refinement:** run `flutter analyze`, unit/widget tests, launch on the available Android target, exercise create/edit/delete/contribution/filter flows and restart persistence, inspect key screen layouts and fix overflow. Report iOS execution limits if no macOS/iOS runtime is available.
6. **Submission:** update README, concise project documentation, known limitations and a timed 3–5 minute live-demo script. Keep generated build/cache output out of the submission source.

**Current implementation status:** a Flutter scaffold was created in `smart_save/` and Riverpod, sqflite, path and shared_preferences dependencies were added before the audit was finished. No feature implementation has been validated yet; those files are provisional and must be revised to match this audit.