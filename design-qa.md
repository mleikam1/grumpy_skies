# PlanCast approved UI verification

Final visual status: **passed**. Reviewed 17 October 2026 on `codex/plancast-approved-ui`, based on `375aca41e8e32e5f0ae06f826820980603051042`.

## Authority and baseline

The actual Today screenshots control identity; `daymaker_plancast_ui_concept_board.png` controls PlanCast composition. All four images in the supplied implementation pack were inspected before implementation. The running baseline was captured before edits (`baseline-native-light-plans.png`). `baseline-native-today.png` is the prior 16 October production capture at the unchanged baseline commit, not a new capture or a fixture-equivalent pixel diff.

Evidence is saved under `/Users/MattLeikam/Documents/Codex/2026-10-15/files-pasted-by-the-user-implement/outputs/plancast-ui/`. Native captures are real 1206×2622 simulator pixels (402×874 logical); their synthetic input is isolated in `integration_test/plancast_smart_locations_preview.dart`. Production does not import that entry point. Images under `responsive/` are explicitly widget-rendered captures with real bundled fonts/artwork, not native-device captures.

## Comparison method and corrections

The source and actual native screens were inspected together in `reference-agenda-comparison.png`, `location-sheet-comparison.png`, and `calendar-sheet-comparison.png`. Source crops and native images are normalized to approximately 402 pixels wide with aspect ratios preserved. The concept's phone panels are 264×884, appreciably taller and narrower than the real device; fitting the concept's four rows into the native viewport would require inappropriate text/control compression.

First pass found excessive persona-card height, inconsistent stat tile heights, redundant calendar-name rows, a narrow agenda/filter collision, and a detail expansion lacking a Material surface. Corrections reduced the portrait/typography footprint, removed duplicate day labels, aligned summary tile heights, moved calendar color into the title with accessible source names, reflowed the filter at large text, and restored detail ink behavior. A second pass checked the corrected native light/dark views and 360/390/430 widget renders, including 2× text at390 and compact cards at all three widths. No unresolved P0/P1/P2 visual findings remain in these checked states.

## Fidelity and accessibility

- Reuses DaymakerSans, DMSpacing, DMTypography, semantic theme colors, DmGlassCard, DmRoastSurface, DmPersonaPortrait, DmPersonaTitleBadge, DmRoastMoodBadge, and the existing animated weather component. No new raster artwork, fake avatars, provider logos, or hard-coded replacement theme.
- Real approved Karen portraits change with the readout mood. All five selectable personas are covered by widget/domain tests. Readouts use local deterministic templates and factual scoped event weather.
- Pale blue backgrounds, white rounded cards, navy/slate text, teal calendar accents, warm yellow controls, subtle borders, and equivalent navy dark surfaces match the intended hierarchy.
- Today keeps its original hero, primary persona/actions, seven-day strip, hourly list, and bottom shell. A widget assertion verifies original persona → daily → hourly → PlanCast order. No production forecast/shell source file changed.
- The compact card shows at most two scoped events and a working footer, without full-agenda prose, repeated Change controls, or a Got it block. Summary semantics remain separate and reconcile with event scope.
- Large text reflows selectors, portrait copy, badges, summary rows, event content, and sheet controls. Tests cover320/1.8×,360/390/430, light/dark, 2× text, long titles/calendar names, keyboard insets, sticky Save/Done, reduced motion, and safe-area layout. Native screenshots validate normal-text iOS light/dark; they do not constitute an exhaustive VoiceOver or physical-device accessibility audit.
- Real native interactions verified Today/Tomorrow/week selection, hotel details, Back/scroll restoration, the compact footer, location-sheet preselection/cancel, and retaining four calendars with Done. Automated tests cover remaining staged changes, scopes, filtering, readout expansion and offline voice failure.

## Justified differences

PlanCast remains a nested route outside the existing bottom-navigation shell, as before. It has Back and does not duplicate the bottom bar or add a fifth tab. Today retains its existing navigation.

Counts, titles, dates, temperatures, categories and sources reflect the fixture/controller, not illustrative board facts. Online rows have no weather. Flights with only a fallback area say Local area forecast. The real hotel title and date span remain intact; full title is accessible and visible in details. Partial and daily-only stay outlooks are labelled. Calendar names/colors replace illustrative account-provider logos. The two sheets open separately, use sticky actions, and accommodate required saved-place/scope/advanced controls, so the location sheet is taller than the cropped concept.

## Verification

955 tests passed in the full available Flutter suite. Static analysis and formatting checks passed. Android debug APK, web release, production iOS simulator builds and the native fixture build passed. The final iOS native bridge smoke test also passed with authorized read-only metadata and unchanged permission. Its output and detailed commands are retained with the review report. Initial introduced layout/test-harness failures were repaired; no failures were suppressed or reclassified as pre-existing.

Seven fixture events across four calendars use two logical venue forecast loads. UI-only day/persona/readout/filter/detail/sheet operations reuse cached state with no additional weather/geocoding calls in tested paths. Fixture adapters perform zero downstream API calls; this does not measure live-provider billing or make a global billing guarantee.

The bridge lacks reliable cross-calendar shared UID data, so similarly titled events remain distinct. City matching is supported; unconfigured exact venue/address lookup remains explicitly unresolved. Provider accuracy, live calendar account integration and physical-device reinstall are outside this visual verification. No release was published or external paid service added.
