# Fixture visual QA — 2026-10-09

These are captures of actual Flutter screens, not reconstructed screenshots.
All weather and roast values in this set are synthetic fixtures. The normal
production entrypoint does not load these fixtures. See `PREVIEW.md` for exact
commands, isolation boundaries, and viewport choices.

## Evidence and results

- `flutter test --no-pub --dart-define=CAPTURE_APPROVED_UI=true test/approved_preview_capture_test.dart`: **46 passed**, 34 seconds after the final proportion changes. Log: `logs/fixture-capture.log`.
- Final reveal screen recapture: **2 passed** (`logs/fixture-reveal-capture.log`).
- Targeted Today light/dark capture after umbrella and compact weather-icon refinements: **2 passed** (`logs/fixture-today-final-capture.log`). The final 46-test pass then regenerated all screenshots, and all six comparison sets were regenerated from that final set.
- Editor/export recapture with an additional memory-autosave assertion: **2 passed** (`logs/fixture-editor-capture.log`).
- Scoped preview analyzer: **no issues** (`logs/preview-analyze.log`). Repository-wide analysis, platform builds, and other tests are recorded separately by the implementation report.
- 47 PNGs in `screenshots/fixture/`: six primary, 22 secondary/state/editor/export, 18 responsive, and one reduced-motion capture.
- Primary viewports: 390×930 logical, text scale 1, rasterized at 2×. Additional primary tests use widths 320, 360, 430, 768, and 1440; large text is 1.35× at 390. These runs found no Flutter layout exceptions.

The first Today light capture was reviewed before the shared components were
propagated. Iteration fixed overflowing hourly tiles, a missing explicit button
font, insufficient quote and weather-icon contrast, portrait scale, the Fun promotion sticker
clipping, and large-text persona-label overflow. Capture tests also exposed an
invalid new meme-template text-zone record; the corrected catalog now loads,
opens a real editor, autosaves in memory, and renders its internal PNG preview.

## Comparison method

`comparisons/{light,dark}_{today,roasts,fun}/` contains a side-by-side image,
50% overlay, raw difference, amplified difference, and JSON transform record.
`tools/compare_approved_ui.py` scales both inputs uniformly to a 390-pixel width,
retains their full content, and records gray padding below the shorter image.
The source dark UI crops are shorter than the canonical light crops; they are
never stretched to force a geometric match.

The supplied `docs/daymaker_exact_ui/tools/compare_screenshots.py` also ran for
Today light in `comparisons/helper_light_today/`. It uses the full app capture
and trims just one bottom pixel from the 340×812 source to obtain equivalent
340×811 regions after uniform resampling. Its pixel-error figures are diagnostic
only: generated concept imagery is not a Flutter golden, and a numerical score
does not establish design acceptance.

## Human review

Today preserves the approved order: wordmark/settings/location, left temperature
and right weather illustration, insight, pink character quote, hourly tiles,
daily rows, and four-destination rounded navigation. Both themes share the same
weather artwork, character, and geometry. The reference's seven-day heading is
intentionally represented as three-day for the three actual fixture records.
The insight says “Rain chance is 40%” because the fixture does not establish a
known current probability from which a rise could be asserted.
The final proportion pass reduced unused hero/card space and navigation height;
all three daily rows are now visible at 390×930 while controls retain meaningful
touch regions. The compact hourly tiles also pass large-text layout checks.

Roasts has the canonical five-persona order, selected Grandpa, a separate
character card and action row, and Karen's crew quote with its real fixture age.
The fixture-only sample disclosure is visible and is not a claim about live
weather. Fun retains the three local tabs, illustrated promotion, three quick
templates, and an editable featured meme. Its decorative sticker is now fully
visible. Existing secondary fun experiences remain reachable below this fold.

Settings light/dark were inspected, including readable selected-mode controls
and all location-button labels. Meme library/editor/internal export preserve the
cream document canvas and caption artwork across app themes. The export capture
is an internal rendered PNG preview; it does **not** prove a native save or share.
The refreshed roast reveal uses the frozen fixture snapshot and a labelled reveal
button; it no longer displays invented location/progression values. Weather-error,
location-prompt, and offline states have readable themed surfaces and actions.

## Remaining visual differences and evidence limits

- Smaller viewports and large-text settings naturally scroll; the final 390×930
  reference viewport shows all three daily rows. No fixed screenshot cutoff is
  imposed on the content.
- Font metrics, some line wrapping, larger accessible controls, artwork details,
  hero shadows/glows, icon stroke/scale, and some surface gradients differ from
  the generated raster. The same light-layout geometry is used in dark mode,
  rather than reproducing the dark board's inconsistent positions and faces.
- Reconstructed artwork is a separate asset-fidelity consideration; consult
  `ASSET_STATUS.md`. These captures do not certify an exact or production-ready
  match to the flattened references.
- Radar uses deliberately transparent in-memory tiles and a blocked backend.
  Only its themed controls/unavailable state are exercised. There is no map or
  provider-coverage validation in this capture set; generic production wording
  about the base map should not be interpreted as evidence of fixture coverage.
- The preview performs no ad requests, native export, telemetry, device-location
  request, real progression write, persistent meme save, or live weather check.
  Device/browser interaction, native builds, keyboard navigation, and assistive
  technology validation require their separately recorded tests; no such claim
  follows merely from these PNGs.
