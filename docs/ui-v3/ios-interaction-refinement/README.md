# iOS interaction refinement

Baseline `fa8ad07b14ac1d3959d2c7bbfbf12e5e751d277f`.

| Capture | View |
| --- | --- |
| [Home light](home-light.png) | Balance, grouped navigation and six Quick Actions |
| [Home dark](home-dark.png) | Palette-derived charcoal theme |
| [Quick Actions close-up](quick-actions.png) | Cropped from a scrolled Flutter render |
| [Savings Goals](goals-light.png) | Fictional savings progress |
| [Investment Intelligence](invest-research.png) | Explore segment and research tiles |
| [AI Assistant](ai-chat-light.png) | Fixture conversation and composer |
| [My Account](my-account.png) | Scrolled to grouped settings |
| [Liquidity Analysis](liquidity.png) | Existing secondary investment tool |
| [Home comparison](home-before-after.jpg) | Baseline left, refinement right |
| [Research selection comparison](research-before-after.jpg) | Baseline left, refinement right |

The mobile theme uses the eleven approved brand colors. Charcoal is a mix of 89.5% near black and 10.5% ice white. Dark grouped records lift that canvas by another 6.5% toward ice white. Tinted surfaces use alpha blends of the palette. Loss and destructive states use separate semantic reds.

Section actions use compact filled pills. Navigation cells pair a full-row target with an icon, trailing chevron and pressed or focus feedback. Home keeps all six Quick Actions above Recent Transactions. Diagonal transaction icons still identify inflows and outflows. Research descriptions were condensed in English, Kazakh and Russian. Disclosures and analytical assumptions remain with their existing features.

Frames were rendered with Flutter at 430 × 920 logical pixels, a 2× pixel ratio, and simulated iPhone safe areas. Captures use an in-memory financial fixture and a stored example chat. Typography uses a local font fallback in the renderer. No physical iPhone or live backend session was used.
