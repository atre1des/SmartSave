# Mobile visual polish

| Existing issue | Planned change | Widgets and behavior |
| --- | --- | --- |
| The balance blends into the canvas and quick actions sit beneath spending | Give the balance a deep green and rich teal surface. Move six compact mint, sage and ice action tiles directly beneath it. | Balance overview and Quick Actions. Keep all six callbacks and add ink feedback. |
| Financial records and progress receive similar emphasis | Keep records on quiet grouped surfaces. Give progress, categories and analytical series clearer teal, slate and seafoam accents. | Home, goals, budgets, transactions, deposits and investment tools. Animate progress changes only when motion is enabled. |
| Chat controls and settings icons blend into the surrounding content | Use restrained tinted surfaces and icon treatments while retaining the transcript and grouped settings. | Composer, prompts, modes, assistant status, history and Account settings. |

The approved UI v3 captures are the baseline. The supplied Wallet, Public, Fuse, Starling, Klarna and Binance references inform financial hierarchy, chart restraint, depth and compact controls. Home's header, balance, recent activity, goals and spending retain their relative order. The five tabs, routes, data and calculations stay in place.

## Flutter captures

| Screen | Capture |
| --- | --- |
| Home | [Light](home-light.png) · [Charcoal dark](home-dark.png) · [Scrolled to Recent](home-recent.png) |
| Savings Goals | [Light](goals-light.png) |
| Investment Intelligence | [Dark](invest-dark.png) |
| AI chat | [Light](ai-chat-light.png) |
| Home comparison | [Original on the left, polish on the right](home-before-after.jpg) |

The captures were rendered by Flutter at 430 × 920 logical pixels with a 2× pixel ratio and simulated phone safe areas. Financial records and the AI transcript are fictional fixtures in an in-memory database. Native-device and live OpenRouter checks are outside this visual review.

## Verification

The Home regression test checks order and localized tile layouts at 320, 390 and 430 px, larger text, the six existing destinations, and reduced-motion progress. During the route checks, the thesis and portfolio headings wrapped and the scenario field was constrained to fit the phone viewport. The existing finance and mocked AI tests remain in the regression suite.
