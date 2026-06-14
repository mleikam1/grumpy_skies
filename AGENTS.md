# DayMaker Codex Instructions

DayMaker is a playful, premium, personality-driven Flutter weather app for iOS, Android, tablet, and web.

Before doing UI, asset, or architecture work, read:

- `docs/DAYMAKER_STYLE_BIBLE.md`
- `docs/DAYMAKER_ASSET_MANIFEST.md`
- `docs/DAYMAKER_CODEX_PLAN.md`
- `docs/DAYMAKER_SCREEN_SPECS.md`

Core rules:

- Flutter builds all real UI: text, buttons, cards, navigation, toggles, inputs, sliders, chips, lists, layout, and dynamic weather values.
- Generated artwork is for backgrounds, mascots, personas, badges, feature illustrations, meme backgrounds, radar overlays, and decorative art only.
- Never bake forecast data, roast text, timestamps, locations, settings labels, or other dynamic copy into image assets.
- The app must compile before final image assets exist. Use fallback placeholders for missing assets.
- Keep one adaptive Flutter UI for iOS, Android, tablet, and web.
- Use shared design tokens, reusable components, accessibility checks, and production-focused implementation.
