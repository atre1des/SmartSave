# Marketing visual polish

| Existing issue | Planned change | Components and interactions |
| --- | --- | --- |
| The hero and floating cards look flat | Concentrate mint, rich teal, seafoam and sage light behind the phone. Add edge highlights and softer layered shadows. | Hero stage, genuine app capture and both financial overlays. |
| Feature blocks have similar emphasis | Alternate ice, sage, mint and deep green. Reserve amber for a small detail. | Existing four feature pillars in their original sequence. |
| The previews and actions lack depth | Refine device frames and showcase backgrounds. Use compact controls, visible keyboard focus and restrained hover and scroll transitions. | Presentation stages, links and buttons. Respect reduced motion. |

The supplied Finotive reference informs the split hero, editorial headline and floating composition. The existing approved marketing captures are the baseline. The nav, all four genuine Flutter captures, How It Works, final CTA and footer retain their content and order.

## Browser captures

| View | Capture |
| --- | --- |
| Desktop, 1440 px | [Hero](desktop-hero.png) · [Full page](desktop-full.png) |
| Phone, 390 px | [Hero](mobile-hero.png) · [Full page](mobile-full.png) |
| Tablet, 768 px | [Viewport](tablet.png) |
| Desktop comparison | [Original on the left, polish on the right](desktop-before-after.jpg) |

The captured page uses the original Flutter screenshots. The accompanying financial overlays retain the original demo values and disclosure.

## Verification

The static build validated 31 references. Chromium checked layout overflow, image loading, fragment navigation and keyboard focus at 360, 390, 430, 768, 1024, 1280 and 1440 px. Mobile navigation was opened with Enter and dismissed with Escape. Captures use Chromium with reduced motion enabled. Safari and Firefox were outside this browser run. The showcase entrance uses CSS scroll timelines when the browser supports them.
