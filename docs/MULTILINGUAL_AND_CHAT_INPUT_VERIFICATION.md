# SmartSave multilingual interface and chat input

## Localization

Flutter generates typed `AppLocalizations` delegates from the English (`en`), Kazakh (`kk`), and Russian (`ru`) ARB catalogs with 672 matching message keys under `lib/l10n`. `flutter pub get` regenerates the ignored Dart output. Flutter's own Material and Cupertino translations cover platform inputs such as date pickers. Unsupported device languages fall back to English.

Open **My Account → Profile → Language** and select **English**, **Қазақша**, or **Русский**. Selection applies immediately and is stored under the signed-in account's UID. A returning account gets its previous choice, including a legacy stored language name. Signed-out screens and accounts without a selection use the supported device language or English. A language change affects presentation. Stored transactions, goal names, investment records, symbols, and chat text retain their original values.

The catalogs cover the principal authentication and onboarding flow, bottom navigation, dashboard, savings and contributions, transaction and budget screens, deposit controls, investment lessons, thesis and scenario controls, both assistant interfaces, profile and privacy actions, and sync notices. The core finance screens use localized date and amount presentation. Amounts remain whole KZT with the existing sign and grouping conventions. ICU messages handle dynamic amounts and plural month counts.

## Assistant and keyboard

The existing system prompt and OpenRouter model are retained. The prompt requests the language of the latest message, honors an explicit language request, and uses the selected app language to resolve ambiguity. Quick actions and their submitted prompts use the interface language. Offline replies use local rules and a script-based language heuristic. Short Cyrillic prompts containing only letters common to Russian and Kazakh can be ambiguous and use the Kazakh app setting as a tie-breaker. Previous chat messages are displayed exactly as stored.

With physical keyboards on Windows, macOS, Linux, and web, Enter and numpad Enter submit once, and Shift+Enter replaces the selection with a newline. Whitespace-only, repeated, and in-progress submissions are ignored. Active IME composition and Control, Command, or Alt combinations are passed through. Android and iOS continue to expose a newline action. The Send button is available across platforms.

## Verification evidence

| Check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Exit 0. Generated localization files were recreated from the checked-in catalogs. |
| `flutter analyze --no-pub` | Exit 0. No diagnostics. |
| `flutter test --coverage` | Exit 0. 56 passed. |
| Focused chat tests | Exit 0. 6 passed. |
| `node --test backend/test/server.test.mjs` | Exit 0. 25 passed with simulated OpenRouter responses. |
| Firestore rules emulator | Exit 0. 9 passed. |
| Auth and Firestore lifecycle emulator | Exit 0. 1 passed. |
| Gitleaks and `git diff --check` | Exit 0. |

Flutter tests exercise account-scoped preference restore, a Kazakh selection through the profile UI in the compact account journey, English/Kazakh/Russian labels and formatters, mocked multilingual prompts and replies, split UTF-8 decoding, progress in the chat before stream completion, persistence and reopening, offline responses, and physical-key simulation with IME composition, and a simulated mobile newline and Send button. These are Linux-host tests. Native device keyboards, web browser and IME behavior, and the full layout of every screen still require hands-on verification.

## Remaining localization and live checks

The migration is incomplete. Some scenario and assessment result narratives, sample product copy, secondary help and advice content, and validation or error text from lower-level services remain English. The interface can still show mixed-language text on those paths. The catalog translations for financial and privacy disclosures should receive native-language editorial review before release.

Live multilingual inference was not tested. This workspace had neither a configured OpenRouter key nor a backend `.env` file. Use the approved test proxy and a signed-in disposable account to verify Kazakh, Russian, English, and mixed-language prompts, streamed Markdown, conversation reopening, and physical and mobile input on the target devices. Keep the API key on the proxy and out of version control.
