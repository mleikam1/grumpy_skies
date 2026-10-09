# Flutter integration plan

## Review boundary and existing architecture

The package author re-read selected remote files on the default branch. Branch metadata reported `d984b2812da8b7d873abcf4b4464be1e07d93e2c`. This is not proof of the owner's current local working tree; inspect that first and reconcile changes. The earlier whole-UI source review used `bedddc8…`; do not reset to either commit.

Current rechecked facts:

- `AGENTS.md` requires real Flutter controls and dynamic text, shared tokens, adaptive layouts, and reading the four `docs/DAYMAKER_*` design documents.
- `lib/design/dm_theme.dart`: `light`, `lightOnDark`, and `dark` all return the same `_lightOnDark` ThemeData.
- `lib/app/daymaker_app.dart`: MaterialApp.router currently supplies `theme: DMTheme.light` and no separate `darkTheme`/persisted themeMode.
- `SettingsController` exposes temperature, persona, notifications and ads preferences but no appearance preference in the fetched file.
- `main.dart` wires the OpenWeather repository/backend/cache, roast-pack repository, location/settings controllers, progression and monetization.
- The shell currently maps five destinations, ordered Forecast, Roasts, Radar, Fun, Settings.
- Persona IDs and aliases already exist; preserve them while changing images and display order.

See SOURCE_NOTES for canonical file URLs and blob SHAs. Do not treat unrelated prompt packs found in the repository as instructions to work on a different app; this task is solely Grumpy Skies/DayMaker.

## Phase 0 — baseline and task setup

Inspect the selected checkout's root, remotes, branch, status, applicable AGENTS files, SDK versions, `pubspec.yaml`, lockfile, entrypoints, target platforms, current tests and docs. Preserve uncommitted changes. Create a non-destructive feature branch when safe, for example `feat/approved-daymaker-light-dark`; do not stash/reset/delete user work just to make branching convenient.

Keep the handoff under `docs/daymaker_exact_ui/` without overwriting unrelated docs. Read both approved images with an image viewer before code changes. Produce `docs/ui_implementation/BASELINE.md` with exact current commit/dirty files, installed tool versions, app entrypoint, actual before captures when runnable, baseline test/analyzer results, and any pre-existing blockers. Do not log secrets.

Run the existing test/analyzer/build workflow available on the user's machine. If unavailable, record the command/error and continue independent work rather than inventing success. No blanket dependency upgrade. No destructive device-data clearing or uninstalling personal-device builds. No production deploy, app-store submission, DNS/IAM edit, billing change, paid tool purchase, or public git push without specific owner approval.

## Phase 1 — canonical assets and shared primitives

Inventory actual image files and their consumers, including typed `DmAssets`, `PersonaAvatar`, featured cards, legacy pages, meme exports and thumbnails. Mark which are still referenced. Follow CHARACTER_AND_ASSET_BRIEF. Introduce versioned new artwork paths without deleting the old files until every usage and old saved-document dependency is understood. Existing user-created memes must still load old asset references.

Build/reuse `BrandWordmark`, `WeatherHero`, `WeatherInsightCard`, `PersonaPortraitStage`, `PersonaSelector`, `PersonaQuoteCard`, `ForecastHourTile`, `ForecastDayRow`, `FunPromoCard`, `TemplatePreviewTile`, `AppSectionHeader`, `ThemedSurface`, and `AppBottomNavigation`, using names consistent with the repo. Prefer evolving the existing Dm-prefixed component set rather than leaving duplicate abandoned design systems.

Give each major component stable test keys and semantic labels. Separate artwork painting from text/control layout. Create a local preview harness with fixture state to tune cards without weather calls. Keep it isolated from production navigation/build defaults. Preview artifacts must be labeled as fixtures in the report.

## Phase 2 — genuine theming and preferences

Implement distinct light and dark `ThemeData` with shared geometry/type, `ColorScheme`, and a small custom `ThemeExtension` for app-specific surfaces such as Karen/Grandpa cards, weather gradients, nav capsules, and Fun promo variants. Add appropriate copyWith/lerp behavior. Do not rely on `ColorScheme.fromSeed` alone to approximate the approved palette.

Wire `theme`, `darkTheme`, and `themeMode` at the actual MaterialApp.router entrypoint. Extend the existing settings model/repository/controller with an appearance enum containing Light/Dark/System. Preserve existing preference serialization and migrate missing/unknown values without wiping any settings. Light is the new-install default. Only System reacts to OS brightness changes.

Review static `DMColors`, `DMTypography`, backgrounds, shared widgets, route headers, dialogs, chips, input fields, switches, sheets, toasts, map controls, editor controls, links, focus rings, and system UI overlay styling. Replacing just `scaffoldBackgroundColor` is not dual-theme support. Old constants containing a white foreground or navy background must migrate to semantic theme access where they appear on themed surfaces. Brand/illustration colors may remain fixed.

Load persisted theme before presenting the first themed frame when practical; match native launch backgrounds sensibly. Avoid a white flash on dark launch. Theme switching must not reconstruct repositories, request location, fetch weather, reroll a roast, clear history, reset tab navigation, or discard a meme draft. Serialize overlapping settings writes or otherwise prevent rapid changes from persisting an older state last.

## Phase 3 — shell/navigation and approved Today layout

Update `lib/app/daymaker_shell.dart`, `lib/shared/widgets/dm_bottom_nav.dart`, route index helpers/assertions/tests and compact safe-area reserve together. The new visual order is Today(`/forecast`), Radar, Roasts, Fun; remove Settings from compact bottom tabs and keep header gears working. Preserve `/home`, `/burns`, `/meme-generator`, `/about` redirects and nested route paths where still supported. Browser reload/back and direct links must work.

Retain monetization route observation, modal observation, operation guards, and weather-safety access. Do not accidentally leave them behind when moving the editor/settings to a different navigator. Use a four-tab state model and appropriate secondary routes. Retain scroll/map/canvas state without letting inactive tabs run animation/polling forever; use lifecycle/route visibility and bounded cache policies.

Implement Today first in Light against the canonical crop, then the same widgets in Dark. Keep asynchronous location-response serial checks, weather freshness, cache safety, supported units/timezone formatting, and existing request coalescing. If state extraction is needed, add a small view model/controller consistent with Provider rather than migrating to a new state framework. The weather insight is computed from real normalized data, not an LLM request per render.

Capture the reference fixture and compare. Fix primary geometry/type/art differences before copying components to other screens. A checkpoint is a work update, not a mandatory approval wait for every ordinary coding step.

## Phase 4 — Roasts and remaining weather screens

Integrate the shared selection/artwork with the actual weather-aware roast pack and displayed snapshot registry. Replace sample-only production behavior only after tracing existing interfaces and tests; keep deterministic sample repositories for tests. Preserve anti-repeat behavior and exact displayed roast handoff. Do not turn a locally selected quote into a live AI call.

Canonical cast display order and IDs are in the asset brief. Profile captions/badges are presentation fields, not identifiers. Keep long quote/large text layouts responsive. History/favorites persist genuine events only.

Restyle Radar around its existing real provider/map implementation. Preserve previous renderable frames during asynchronous frame replacement, check timing/source/coverage, stop playback offscreen/background, and handle no-tiles failures. Do not fabricate a six-hour future forecast when the provider/account/region does not support it. Do not add new provider subscriptions. Keep provider attribution and safety controls visible.

Implement matching forecast details, location selection, cache/error/permission states and real warning details. No new weather API credentials are needed merely to build theme support. Existing credentials remain in their secure backend configuration; never place them in app assets or source.

## Phase 5 — Fun, library, editor, and export

Build the approved Fun above-fold layout, with functional Make a meme/Templates/My memes views. Preserve existing fortune/prediction/menace experiences below the pictured fold or in matching secondary collections. Do not silently delete features to match a crop.

Integrate with `lib/features/fun/meme/` rather than replacing the editor. Preserve `MemeDocument`, its IDs/schema, local store/backends, autosave/recovery, media references, imported photos, layers, undo/redo, export preview and native/web sharing. Existing generated asset IDs in saved documents may need an alias/migration map. Do not delete old image sources still referenced by user projects.

Apply theme-aware chrome to the editor but do not let the app theme recolor the user's exported artwork. A meme's background/text colors are document state, not inherited app chrome. Persist draft identity and edits through theme change/navigation/lifecycle. Layered template captions stay editable; render labels separately from static art.

Do not insert ads into the canvas, import picker, system share flow or mid-export operation. Keep existing guards until the explicit completion transition has actually occurred. Cancellation is not successful sharing or a reward event. On unsupported share platforms provide supported save/copy feedback, not fabricated success.

## Phase 6 — Settings, About, onboarding, and monetization styling

Finish appearance picker and all other real preference paths. The default persona row must open a working selector. Notification preference, system permission, scheduling/delivery configuration and actual status are distinct; do not show “notifications are on” from a static snackbar. Preserve configuration and explain unsupported delivery instead of pretending to enable it.

Use actual package/build version, functioning legal/license views, and owner-approved feedback/contact destination. Do not invent privacy guarantees or business details. Any missing production policy/contact is an explicit release blocker, not a reason to skip the UI.

Retain ad placement IDs, creative sizes, consent state and gating rules. Ads are not part of the illustrated above-fold target. Keep them in the existing eligible below-content positions and make the surrounding surface theme-aware. The creative itself is not inverted, filtered, cropped or resized to fit the theme. Do not add formats or increase frequency as a by-product of restyling. A no-fill/ineligible state must not leave a misleading fake advertisement.

## Phase 7 — test, capture, compare, refine

Use the supplied fixture to create six consistent actual Flutter captures: Today/Roasts/Fun in Light and Dark. Match reference-width and text-scale context before comparisons; the source boards lack trustworthy original device metadata. Use the same selected state/data between paired themes. Match Light geometry in both, not two independent screenshot coordinate layouts.

Use `tools/compare_screenshots.py` where suitable after cropping equivalent app/component regions. Inspect overlays and difference images; never non-uniformly stretch the candidate to hide mistakes. Test selectors/buttons/settings sheets, long text, absent data, small screens and reduced motion. Use deterministic Flutter goldens after establishing reviewed actual reference captures; do not regenerate goldens just to bless a regression.

Execute format/analyzer/unit/widget/integration tests, then supported local web/Android/iOS builds. Use actual available SDK commands and document exact targets. No model or prompt can guarantee access to Xcode, a signing identity, a physical device, a working weather credential, or an image-generation tool merely because the computer is accessible. Report blocked paths with evidence and continue other tests.

## Deliverables inside the repo

```
docs/ui_implementation/BASELINE.md
docs/ui_implementation/PROGRESS.md
docs/ui_implementation/ASSET_STATUS.md
docs/ui_implementation/THEME_ARCHITECTURE.md
docs/ui_implementation/ACCEPTANCE_RESULTS.md
docs/ui_implementation/FINAL_REPORT.md
docs/ui_implementation/screenshots/light/today.png
docs/ui_implementation/screenshots/light/roasts.png
docs/ui_implementation/screenshots/light/fun.png
docs/ui_implementation/screenshots/dark/today.png
docs/ui_implementation/screenshots/dark/roasts.png
docs/ui_implementation/screenshots/dark/fun.png
```

Also capture key secondary screens in both themes, asset comparisons, overlays/diffs, test output summaries, and concise local run instructions. Separate actual captures from source concept art and fixture captures from live-data checks. Report modified files, dependency changes, broken-baseline versus newly introduced failures, remaining visual differences, migration/rollback notes, and owner-only blockers.

If time/session limits interrupt work, leave a durable progress record with the next exact action. Do not return a plan as if implementation were done. Conversely, do not claim production readiness while high-resolution identity-matching assets, platform tests, or production configuration remain unverified.
