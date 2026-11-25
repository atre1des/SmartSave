# Stage 10 · Desktop control proportions

Baseline `dc5bc7e993cfeb06d795afa0421fba5a1bda22d9`. All captures are from the actual Flutter Web app in Chromium at 1440 × 1000. The authenticated views use disposable local Firebase emulator accounts.

## Before and after

| Control | Before | After |
| --- | --- | --- |
| Add transaction | 1,135 × 32 logical px. [Before](before-home.png) | 161 × 48 logical px including the hit target. [After, same empty state](after-home-empty.png) |
| Sign in | 440 × 32 logical px. [Before](before-auth.png) | 91 × 48 logical px including the hit target. [After](desktop-authentication.png) |

The body columns intentionally stretch records and form fields. Raw action buttons in those columns inherited tight horizontal constraints. The account controls inherited the same constraint, and the conversation list gave New Chat the width of its selectable rows. The editor and confirmation footers already grouped actions with natural widths, so only their desktop control sizing and padding needed adjustment.

At 1024 px and wider, standalone web actions are given loose width constraints with a maximum of 360 px. Finance actions share the heading row, and related auth and account actions wrap with consistent spacing. Desktop controls use a minimum visual height of 44 px and padded keyboard and pointer targets. Existing Material button states and UI v3 colors and shapes remain in use.

Phone and tablet form actions retain the full-width layout below 1024 px. Sidebar destinations and conversation history selections still span their own narrow navigation columns. Their width makes the selection and hit area clear. Form inputs, chart panels and financial record groups retain their existing widths.

## Corrected captures

- [Desktop Home · Light](desktop-home-light.png)
- [Desktop Home · Charcoal](desktop-home-dark.png)
- [Desktop Investment Intelligence](desktop-invest-light.png)
- [Desktop AI Chat](desktop-ai-chat.png)
- [Desktop Authentication](desktop-authentication.png)
- [Desktop Financial Editing](desktop-financial-edit.png)
- [Desktop Delete Confirmation](desktop-confirmation.png)

The Chromium test lives in `tool/stage10/button_refinement_test.py`. Run it against the [Phase B emulator setup](../PHASE_B_VERIFICATION.md#reproduce-the-local-browser-checks).

Flutter analysis reported zero diagnostics, all 66 Flutter tests passed, and both the normal web build and the emulator build completed. Chromium passed the desktop keyboard focus and Enter activation checks, EN/KK/RU label checks, both themes, and layout and editor checks at 1024, 768 and 390 px. The compact checks measured the fully scrolled-into-view controls and checked for horizontal page overflow. No visual issues were observed in the reviewed captures.
