# DayMaker Fun section — visual QA and fix pass

The DayMaker Fun redesign has already been implemented on the current branch. Perform a hands-on visual, interaction, accessibility, and regression QA pass against the five supplied references. **Fix the implementation during this task. Do not return only an audit or issue list.**

## References

1. `daymaker_fun_design_refs/01_fun_zone_landing.png`
2. `daymaker_fun_design_refs/02_cloud_fortune_tap.png`
3. `daymaker_fun_design_refs/03_cloud_fortune_reveal.png`
4. `daymaker_fun_design_refs/04_meme_editor.png`
5. `daymaker_fun_design_refs/05_meme_result_share.png`

The screenshots show visual intent, not fixed coordinates. Never reproduce the pictured status bar, home indicator, or any debug ribbon as app content. Use the real platform system bars, safe areas, and existing bottom-navigation shell.

## Rules

1. Inspect the current diff and relevant architecture before changing anything.
2. Preserve working routes, weather services, state management, storage, localization, analytics, entitlement logic, and unrelated features.
3. Keep fixes narrowly scoped to the Fun redesign and regressions caused by it.
4. Compare at the same viewport, text scale, and UI state. A screenshot by itself is not a comparison.
5. For each state, place the reference and implementation capture together in the same visual comparison input and judge the visible differences from that combined view.
6. Fix visible problems, recapture, and compare again. Repeat until no material mismatch remains.
7. Do not replace production art with placeholders, emoji, text glyphs, CSS/code drawings, or screenshot crops.
8. Do not stop because a test or build fails due to your changes; diagnose and fix it. Report pre-existing failures separately.

## Capture matrix

Capture and compare:

| State | Required content |
|---|---|
| Fun landing | Meme Generator first, Cloud Fortune second, compact secondary features, real bottom nav |
| Cloud ready | full cloud, instructions, Tap/Pop/Reveal, Tap to Pop, daily footer |
| Cloud revealed | burst/open cloud, fortune card, weather vibe, both actions, footer |
| Meme editor | live preview, style chips, both fields, forecast toggle, four primary actions |
| Meme result | final clean meme, style summary, Share, Save, Remix, New Background |

Use a common 390–412 logical-pixel phone width first. Also check roughly 320/360 and 430 logical pixels, a large phone, and a tablet/max-width presentation when supported.

## Visual comparison checklist

For every screen, inspect and correct:

- hierarchy and whether the primary action is immediately obvious
- exact content order and grouping
- safe-area treatment and bottom-nav clearance
- page/card margins, internal padding, rhythm, and alignment
- type scale, weight, line height, wrapping, and truncation
- card and button height, radius, border opacity, gradients, and glow restraint
- image aspect ratio, focal point, crop, resolution, and safe text zones
- icon family, optical size, baseline, and selected/disabled states
- foreground contrast over surfaces/images
- narrow-width overflow and excessive empty space on larger devices
- text-scale 1.3 behavior
- keyboard-open behavior in both meme text fields
- status/navigation bar theme and removal of any debug ribbon

Prioritize fidelity in this order: structure/hierarchy, spacing/sizing, typography, imagery/crop, color/gradient/glow, micro-details.

## Interaction QA

Exercise and fix these paths:

1. Landing → Meme Editor → template picker → edit both captions → move/scale text → add/move/scale/remove a sticker → undo/redo → Generate → Save/Share → Remix → back with draft preserved.
2. Landing → Cloud Fortune → tap cloud rapidly → burst/reveal → share → reopen on same local day → canonical fortune remains stable → bonus/replay behavior remains correctly labeled.
3. Open every secondary Fun feature and return without losing bottom-nav state.
4. Toggle reduced motion and confirm Cloud Fortune uses a short accessible transition.
5. Test offline after assets are installed; all 15 templates, thumbnails, fortunes, and editor actions must still work.
6. Force missing weather data, storage corruption for feature-only state, share failure, and save-permission denial. Confirm useful errors and no lost draft/result.

Check that cloud input is ignored during the active animation, export omits editor controls, the DayMaker badge follows real Pro rules, no extra weather request is made for captions/fortunes, and analytics never contain user-entered text or image content.

## Accessibility QA

Use the platform/framework accessibility tools available in the repository and fix:

- missing or ambiguous semantic labels
- incorrect focus order
- controls below 48 × 48 logical pixels
- selection communicated only by color
- unreadable contrast
- clipped content at text scale 1.3
- keyboard focus hidden behind the keyboard/bottom nav
- particle motion/flashing that ignores reduced motion or risks discomfort

## Automated and regression checks

Run the repository's formatter, analyzer/linter, full relevant tests, debug build/run, and a release/profile build when feasible. For Flutter, this usually means `dart format`, `flutter analyze`, `flutter test`, a debug run, and at least one platform build.

Confirm at minimum:

- 60+ fortunes are unique and validate
- canonical fortune stability/date rollover/weather fallback are tested
- all 15 templates and referenced asset files validate
- filters, favorites, caption fallbacks, character limits, undo/redo, and persistence are tested
- all landing and primary-flow navigation tests pass
- no overflow, uncaught exception, broken image, dead control, duplicated nav, or fake system UI remains

## Completion report

Only finish after the final recaptures have been compared against the references and material discrepancies have been fixed. Return:

1. exact fixes made, grouped by screen
2. exact files changed
3. final five screenshot paths
4. test/build commands and results
5. any pre-existing failures separated from new results
6. genuine remaining differences with a reason they could not safely be corrected

Begin by inspecting the current implementation and capturing the five states, then fix and recapture until the definition above is satisfied.
