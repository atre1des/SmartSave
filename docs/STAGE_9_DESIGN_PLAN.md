# Stage 9 screen audit and migration plan

The current app uses a single light Material 3 theme. Shared cards, buttons, chips and progress tracks and many screens override it with fixed colors. The two Markdown renderers and the welcome SVGs also carry independent colors. The migration starts with a shared semantic theme, then replaces those overrides without changing routes or state.

| Existing screen or surface | Planned treatment |
| --- | --- |
| Startup, authentication failure and storage recovery | Apply the same themed canvas, text and progress indicators available before login. |
| Welcome | Keep the artwork and actions. Recolor existing SVGs using the official palette and preserve the scroll layout. |
| Sign in, registration and password reset | Use shared fields, focus and error borders, segmented controls and action buttons. |
| Email verification | Use shared actions and readable status icons. |
| Onboarding and sample card setup | Apply themed illustrations, progress, bank chips and sample-data notices. |
| Card connection failure | Give the explanation and recovery actions distinct notice styling. |
| Both risk quizzes and the sample risk result | Use shared selection states and progress. Keep questions, scoring and destinations. |
| App shell | Theme the five destinations, including the selected icon and label. Keep the existing tab and back-navigation behavior. |
| Dashboard | Keep the balance as the main emphasis surface. Use quiet cards for shortcuts and goals, shared progress and themed transaction cues. |
| Total balance, spending tab and transactions tab | Keep chart values and switch to theme-specific series and legends. |
| Goals list, progress, goal editor and savings plan | Apply shared cards, meters and form controls. Retain contribution and deletion dialogs. |
| Transactions list, detail and add/edit | Theme search, category chips, amount display, editing and deletion actions. |
| Spending analytics and category detail | Use the official chart series and keep category text and signs alongside color. |
| Deposits, details, calculator, comparison, rationale and goal picker | Use neutral cards, themed filters and fields, and retain terms, rates and all comparison controls. |
| Deposit no-results route | Use a quiet empty state and keep both recovery actions. |
| Investment hub, stock list and stock detail | Theme watchlists, profiles, charts and opportunities. Reserve amber for selected insight accents. |
| Bonds, bonds preview and recurring investment | Theme educational notices, cards, form controls and allocation. Keep demo limitations. |
| Investment Intelligence lessons | Theme topic cards, tab navigation and the lesson sheet. |
| Thesis list, editor and detail | Theme cards, form controls, evidence badges, empty states and assessment history. Keep evidence labels visible. |
| Condition editor | Theme thresholds, evidence fields and action states. |
| Liquidity and macro scenarios | Theme calculators, charts, result cards and portfolio holding sheets. Preserve textual warnings and calculations. |
| Recommendations, spending advice and auto-save preview | Theme disclosures and action choices. Keep advice and transfer boundaries intact. |
| Online assistant, drawer and Markdown | Apply shared composer, bubbles, status banners, Markdown links and code surfaces. Keep keyboard and streaming behavior. |
| Local assistant and launcher | Use the same semantic palette and preserve overlay visibility and chat navigation. |
| My Account and legacy profile | Apply themed cards, profile shortcuts, risk and goals. Add a localized appearance control in Profile settings. |
| Profile details, connected accounts and notifications | Theme input and selection controls. Persist appearance on this device and preserve account language settings. |
| Advice history, subscription and help | Use themed cards, indicators and disclosure text. |
| Privacy, export, recovery, sync and deletion | Preserve permission and confirmation paths. Use themed dialogs, warning icons, outlines and explicit labels. |

Use the official palette through semantic tokens, including neutral canvas, surface, text, action, progress, chart and status roles. Verify both themes, locale catalogs, persisted appearance, and existing financial and assistant regressions.

## Implementation and checks

The shared theme assigns the official colors to independent light and dark roles. Light uses the ice canvas and white cards. Dark uses the near-black canvas with deep teal and slate surfaces. The selected navigation destination places its label and icon on the same selected surface. Statuses retain their labels and icons, and the amber accent is used for an investment suggestion.

The localized appearance setting is under **My Account → Profile → Appearance**. The device stores Light, Dark or System across restarts and sign-in changes. Language remains an account preference. The theme applies to the startup and sign-in routes as well as the signed-in shell.

Locked Flutter dependency resolution, Flutter analysis, the full Flutter suite with coverage, and the Git whitespace check exited 0. All 64 Flutter tests passed. Tests cover the compact account journey in both themes, changing appearance from a Kazakh profile route, persisted selection, system brightness, and representative normal-text contrast. A source check confirmed that the Dart color literals, SVG artwork, and web manifest use the 16 approved colors. Native-device visual review and a full responsive web review remain open.
