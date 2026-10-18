# Wingman Weather Codex Instructions

Wingman Weather is the current Flutter weather app for iOS, Android, tablet, and web.

The October 2026 Wingman update retired every persona and the Roasts experience. Do not restore persona selectors, generated roasts, or their startup services. Preserve the current horizontal daily forecast, vertical hourly list, factual PlanCast briefings, Fun/meme tools, and weather animations. Older DayMaker documents below remain useful for unrelated layout/theme rules; their persona/roast product requirements are historical and superseded.

Approved branding and deterministic asset regeneration are documented in `docs/wingman_brand/README.md`. Keep package/bundle IDs, storage IDs, backend endpoints, and provider identities stable.

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
