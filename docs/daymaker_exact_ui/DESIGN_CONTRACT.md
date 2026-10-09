# Design contract — preserve the approved design

## 1. Binding product decision

Use the new illustrated cast in these approved boards. Earlier instructions to preserve the original repository artwork are superseded for character appearance. Preserve IDs, preferences, voice/content rules, unlock state if applicable, and existing user data. Change the image mapping, not the user's identity/state.

This is a faithful implementation, not an invitation to invent a new UI. Do not substitute generic cards, emoji avatars, stick figures, stock photos, the earlier simple SVG cast, or the first dark board with Frat Bro as its featured character.

## 2. Authority and conflict resolution

1. Owner's current request: the same approved UI in light and dark mode; characters from the designs.
2. `references/approved/light_board.png`: canonical component arrangement, spacing relationships, typography hierarchy, character appearance, initial example composition, and static UI copy.
3. `references/approved/dark_board.png`: dark surfaces, contrast, atmosphere, and color treatment of that same composition.
4. This contract and the screen specification resolve inconsistent details in the generated boards.
5. Tokens and measured crop geometry are implementation starting values, not exported designer source values. Adjust them to improve the match.
6. Older project design proposals are historical, not an alternative visual target. Existing safety, security, data, and functional requirements remain in force.

The dark board contains slight generated variations in character drawing, geometry, and labels. Do not build those as separate layouts. Use the light layout and one shared set of canonical light-reference character assets, then apply the approved dark palette. In particular, keep the light card's role/badge arrangement and the same hourly list, same selected persona, same copy, same icon mapping, and same relative card positions when comparing themes with identical state.

## 3. What belongs in the app

Implement only the UI inside the phones. Poster headlines, side notes, decorative characters outside the phones, phone bezels, mock device shadows, the fixed 9:41 status bar, and the 2024 concept footer are not app screens. Render real system status/navigation areas with appropriate system icon contrast; do not fake them as images.

Keep `daymaker.` as the in-app wordmark shown in the approved UI. Centralize display branding so it can change later. Do not rename the repository, package IDs, Firebase project, iOS bundle identifier, app-store listing, or domains as an incidental UI change.

## 4. Shared layout across themes

Create one widget tree for each feature, one shared set of spacing/typography metrics, and a semantic color layer. A theme switch changes backgrounds, foregrounds, borders, shadows, and appropriate decorative surface variants only.

It must not change routes, current tab, scroll offset, selected persona, weather, draft state, content order, card height, or the meaning of a control. Weather day/night and application light/dark mode are independent: a dark UI at noon still shows the actual daytime weather icon. Never tint/invert/desaturate the character illustrations to make dark mode.

Appearance choices: Light, Dark, System. New installs default to Light for this approved design; respect any pre-existing explicit preference when migrating. System follows the device dynamically only while System is selected. Persist the user's choice locally, with a backward-compatible default for older records. Prevent a bright startup flash when Dark was saved.

## 5. Visual character

Light: pale ice-blue/near-white background, gentle sky haze in the weather hero, warm sunshine yellow, deep ink text, translucent-looking but readable white cards, a pink Karen card, a pale warm-pink Grandpa card, clean restrained shadows.

Dark: deep midnight navy, slightly lifted blue surfaces, white and muted blue-white text, restrained indigo borders and glows, deep plum Karen surface, deep blue Grandpa surface, bright yellow actions. Do not turn it into a black/gray utility dashboard or the earlier purple-heavy alternate concept.

Both: confident rounded sans-serif hierarchy, very large weather number, softly rounded rectangular cards, compact controls, weather art with soft dimensional shading, consistent icon weights, and a four-destination capsule navigation bar.

## 6. Canonical navigation

Compact order: **Today · Radar · Roasts · Fun**. Display Today while preserving `/forecast` as the route. Settings is reachable from the header gear. Preserve `/settings` and all nested routes/legacy aliases.

Selected tab: yellow rounded rectangle inside the capsule, dark icon and label. Inactive tabs use a muted blue in light mode and pale muted blue in dark mode. Use identical nav geometry in both themes. Respect system bottom insets and large labels; no content is hidden behind navigation.

Settings and About should not falsely highlight Today as if that were their selected tab. Use a secondary route presentation with a clear Back action; hide bottom tabs for full-screen settings/editor workflows when appropriate. Preserve monetization route/modal observation and weather-safety access even when chrome is hidden.

## 7. Baseline geometry and type

The phone boards are compositions, not device screenshots with trustworthy original dp metadata. Work at a 390 logical-pixel mobile reference width, matching the image proportions and relative positions. Use approximately 18 logical-pixel page padding, 12–16 between groups, 20–24 card radii, and 14–16 control radii, then adjust from captures.

At the reference width and normal text scale, preserve the main sections visible in each approved phone. On shorter screens let content scroll rather than shrink the whole screen. On narrow screens use responsive wrapping, not illegible text. Never use a root FittedBox or a screenshot stretched as the UI.

Choose a legally available bundled or system font that matches the visual reference; inspect existing font assets and licenses first. Nunito is a candidate already declared by the repo, not a verified exact match for the mockup. Exact original font identification is unavailable from the raster boards. Do not download/share proprietary system font files or add runtime font-network calls. Use consistent tabular weather numerals and retain contrast under text scaling.

## 8. Content and truth

The 72° temperature, Overland Park location, 40% rain chance, Karen quote, Grandpa quote, and displayed timestamps are visual-test examples. They are not live conditions. Use the supplied fixture only through an explicitly isolated preview/test entrypoint. Never fall back to that weather in a production error state.

Keep dynamic temperature, forecast labels, locations, times, roast text, captions, selected state, progress, and buttons as Flutter-rendered content. Correct obvious generated typo/inconsistency without redesigning. For example, weather icons must agree with the real weather model even if a generated dark thumbnail differs.

A LIVE chip is conditional on actual fresh data; use Updated, Cached, Stale, or Unavailable as appropriate. Place a small real observation time/source line in an available slot without hiding required disclosure. An insight such as rain at 5 PM needs actual forecast support. Safety alerts take priority, and serious warnings are not punchlines.

## 9. Asset contract

Approved character art is immutable across theme changes. Backgrounds and halos belong to the layout/surface, not baked into the face art. Use shared transparent PNG/WebP or suitable vector artwork. Keep full source artwork and license/provenance notes under a separate project asset directory; integrate only optimized assets into the Flutter bundle.

Do not apply hard color-key transparency to the board crops: it will erase parts of skin, hair, cloud highlights, and clothing. Do not embed a cropped text/button card as an image with invisible controls on top. No large full-body versions of Frat Bro, Politician, or the toddler are present in these approved boards; any new larger artwork is a reconstruction, not an extracted original.

## 10. Accessibility, motion, and fidelity

Maintain minimum 48 × 48 logical-pixel interactive regions, even where the visual icon/button is smaller; avoid hit regions overlapping adjacent controls. Body text should stay readable with up to 200% text scaling. Use semantic labels, selection announcements, focus order, keyboard actions, and high-contrast focus indicators. Provide button/keyboard alternatives for drag-only features.

Use restrained transitions of about 140–220 ms. Do not animate the entire UI to disguise layout jumps. Honor system reduced motion and app preference; suppress decorative loops during background/inactive states. Verify contrast on actual gradient/image composites, not just isolated token pairs.

A side-by-side/overlay pass at equivalent widths must examine card boundaries, type baselines, line wraps, portrait sizes, image fit, navigation, and button alignment. Small anti-aliasing differences do not justify accepting a clearly different design. Pixel metrics from differently sized generated references are diagnostic, not proof of exactness. Do not assert pixel-perfect completion without actual captures and a disclosed comparison method.
