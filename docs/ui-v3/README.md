# SmartSave Phase A — Reference-driven redesign

This review covers Home, Investment Intelligence and AI chat on `experimental/ui-v3-liquid-glass`. The previous Phase A captures are preserved in commit [909248b](https://github.com/atre1des/SmartSave/tree/909248b430f24564ffe6e14504a8f36a266aa199/docs/ui-v3).

| Screen | Light | Dark |
| --- | --- | --- |
| Home | [Dashboard](light-dashboard.png) | [Dashboard](dark-dashboard.png) |
| Investment Intelligence | [Invest](light-invest.png) | [Invest](dark-invest.png) |
| AI Assistant | [Chat](light-ai-chat.png) | [Chat](dark-ai-chat.png) |

## Reference mapping

| Attachments in display order | SmartSave application |
| --- | --- |
| 1–2 · Apple Wallet | Move the amount and label out of a heavy card. Use right-aligned transaction values, a single grouped activity surface and quiet dividers. Balance detail remains outside this review. |
| 3 and 9 · Fuse Plus, repeated attachment | Use a soft charcoal dark canvas, with limited surface tint and big type. Apply this restraint to the chat transcript and market overview. |
| 4 · Binance | Place signed data in a zero-centered analytical chart. Use selectable market and research views. |
| 5 · Starling | Give the balance its own atmospheric space. Place records lower on the page, on a distinct surface. |
| 6 · Public portfolio | Give price comparisons shared space and a common scale. Keep section navigation and the dock compact. |
| 7 · Klarna | Use a floating capsule, compact prompt controls and layered sheet interactions. |
| 8 · Public investing introduction | Use strong contrast and generous space around research controls on the dark canvas. |
| 10 · Fuse wallet | Give the primary financial amount larger tabular figures and separate supporting labels and amounts. |

## Changes from the previous Phase A

- **Home** replaces the gradient balance card with a larger open balance area and a localized monthly spend and budget line. Research has a dedicated link beside the financial summaries. The two most recent transactions share a single inset group, followed by savings progress and the existing spending details and shortcuts.
- **Invest** separates the sample market overview from research. Four existing sample changes share a signed chart with a common zero baseline. Stock detail links and the AI investment entry remain visible in the market view. Theses, liquidity and economic scenarios are available in Explore. The chart shows existing illustrative values side by side, with no historical series or live feed.
- **Chat** replaces assistant bubbles with a readable markdown transcript interleaved with right-aligned user messages. The composer keeps input, mode and send controls on one line when collapsed, and grows for multiline text. A scrollable history sheet replaces the drawer and retains saved-chat controls and research links.
- **Navigation** retains the five localized destinations and moving highlight. The capsule now has more internal breathing room and a quieter selection tint. Home and Invest scroll beneath it and have trailing space to bring the last item clear.

The six images are actual Flutter widget renders at 430 × 920 logical pixels, exported at 2×. They use one local SQLite fixture with fictional financial records and a saved fictional conversation. The capture renderer uses Noto Sans and DejaVu glyph fallbacks. The chat status reflects the offline fixture.

The dark canvas blends the approved black and ice colors for a softer charcoal backdrop. The floating control materials use clipped Flutter blur, an opaque high-contrast fallback and a reduced-motion selection mode. Native iOS glass and device-level keyboard, safe area, Reduce Transparency and frame timing still need device review. No new packages were required.

Flutter analysis finished with zero diagnostics. The complete Flutter suite passed 65 tests with coverage enabled. The two compact account journeys exercise the new research segment and history sheet. Streaming and conversation persistence were exercised with mocked requests.
