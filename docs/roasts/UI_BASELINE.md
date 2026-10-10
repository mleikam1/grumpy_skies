# UI preservation baseline

## Authoritative source

- Repository: `/Users/MattLeikam/Documents/Codex/2026-09-17/files-pasted-by-the-user-work/outputs/grumpy_skies`.
- Remote: `git@github.com:mleikam1/grumpy_skies.git`.
- Branch: `feat/approved-daymaker-light-dark`.
- Starting HEAD: `6f67fb11ff4030ae3a1cb1074c7f7b028769bd80`, also the locally available `origin/main` and `origin/HEAD`.
- Initial staged/unstaged/untracked status: **clean**. No local-versus-remote difference at the captured starting refs. A safe fetch and current remote validation are recorded separately by the implementation owner.
- Starting history includes `6f67fb1` (forecast/radar/persona refinements), `d259422` (approved light/dark UI), and `bedddc8` (prior baseline/native/browser/build verification).
- No reset, clean, pull, old-revision checkout, replacement branch, clone, stash, uninstall, storage reset, or historical UI restoration was used.

`ui_protected_baseline.json` was written before implementation edits and contains the initial status/ref record plus 86 protected SHA-256 values. `ui_extended_protected_baseline.json` supplements it with all tracked artwork and shared/feature presentation files, read directly from the same clean starting HEAD. `ui_display_contract_baseline.json` adds the reveal/share, identity and persisted-appearance contracts from that same starting HEAD. All source manifests are immutable. Runtime roast JSON is excluded from the extended artwork manifest because updating catalog content is authorized.

## Production entrypoint and route trace

Production is `lib/main.dart` → `GrumpySkiesApp` → `DaymakerApp` → `daymakerRouter` → `DaymakerShell`. No build flavor is required. At baseline, main creates `OpenWeatherBackendClient`, `OpenWeatherRepository`, `RoastPackRepository`, `PackRoastRepository`, persisted settings/location controllers, `DisplayedRoastRegistry`, progression services and monetization controller. The router and shell retain ad/modal safety observation. `README_DAYMAKER_UI.md` describes obsolete runtime setup; it is not production authority.

The shell order is **Today → Radar → Roasts → Fun**. `/forecast` uses `ForecastScreen`; `/radar` uses `RadarScreen`; `/roasts` uses `RoastsScreen`; `/fun` uses `FunZoneScreen`. `/roasts/reveal`, `/fun/meme`, `/settings`, and `/settings/about` remain in their existing flows. Legacy compatibility redirects stay redirects. `main_preview.dart`, `lib/pages/`, and `lib/features/roasts/pages/roasts_page.dart` are not production starting points.

## Approved presentation and available slots

- Today: existing hero/metrics/insight → one `ForecastRoastCard` → hourly strip/daily grid/details. Keep portrait, persona title, mood badge, quote, Another/Share actions and source/status labels.
- Roasts: existing persona selector → “MEET YOUR FORECASTER”/featured portrait and card → action row → crew/history. Keep its location/weather footer, badges and responsive layout.
- Hourly/daily: current tiles/rows and sheets have **no inline roast-text slot**. Commute/weekend likewise have no approved placement. Matching data support may be added, but production placement stays pending a separate UI change.
- Radar: existing map/controller/timeline/layer/error flow remains. Map fixture evidence below does not claim live city-label readability.
- Fun/meme: existing library/editor routes and document schema remain. Existing displayed snapshot is the handoff authority.

Both themes use the same layout. `DMTheme` and `DMSemanticColors` define appearance; Light/Dark/System persists through the existing settings controller. The default is Light. Weather day/night is independent from appearance. Light styling and radar OSM/NOAA changes are present in the starting revision, as documented by the prior refinement reports. Those historical reports are not this session's runtime verification.

**Requested filled-icon refinement is still pending:** `ForecastHourlyStrip` and `ForecastDailyGrid` explicitly use `WeatherIconStyle.line`. This task must preserve that actual approved source, not claim a later filled-icon implementation exists. No icon package upgrade/replacement is included.

`RoastMood`, `RoastMoodResolver`, `PersonaEmotionAssets`, `DmPersonaPortrait`, and `DmRoastMoodBadge` remain the expression system. Canonical IDs are karen, frat_bro, grandpa, politician, two_year_old; aliases remain compatible. All 50 `assets/personas/<persona>/<mood>.png` files exist at baseline. The fallback chain is requested mood → same-persona neutral → retained `assets/approved_v1/personas/<persona>_portrait.png`. Portraits use contained, untinted local art. Original asset hashes are protected.

## Deterministic capture evidence

`ui_evidence/baseline/manifest.json` records **74 immutable PNGs** and their SHA-256 values. Capture tests passed **16/16** in this session. The capture writer refuses to overwrite an existing baseline file; no historical goldens were changed.

`test/roasts/ui_preservation_capture_test.dart` injects test-only repositories/settings/clock into the **actual active production screen classes and DaymakerShell**. It does not launch `ApprovedPreviewSession` or a preview screen, and no production providers are replaced. The harness duplicates only test dependency setup and fixed data. It uses frozen 2026-10-12 10:00 America/Chicago weather, selected public city Overland Park, fixed persona/quote inputs, loaded application fonts, disabled motion, pixel ratio 1, in-memory settings/memes and offline map tiles. This is controlled fixture evidence, not live weather or a native installation.

Captured in Light and Dark at **390×844**, **320×844 with 200% text**, and **820×1180 tablet**:

- Today initial viewport and scrolled roast card;
- hourly and daily sheets with the fixed close header and navigation occlusion assertion;
- Roasts initial viewport and featured card;
- Radar in its deterministic offline/transparent-map fixture state;
- Fun entry and Appearance settings.

`ui_preservation_emotion_capture_test.dart` additionally captures the actual Today/featured card variants for all five personas in both themes and all ten local expressions per persona. Those galleries use 390×1100 and 780×860 to expose the full card/artwork; they supplement the exact phone/small/tablet screen captures.

Important provenance limit: the source checksum record preceded **all** implementation edits. Screen captures completed before any production screen/wiring edits, but concurrent isolated selector work had already started. The deterministic Today fixture therefore selected the new context-free Karen line, “I have opinions. The suggestion box has been warned.” with neutral mood; Roasts uses its fixed injected quote. These screenshots establish presentation with recorded display inputs, not a claim that the old selection algorithm produced that new fallback. Final comparison must preserve these exact display inputs. No UI-fidelity sign-off is claimed until final comparisons are recorded.

## Verification commands and limits

```sh
flutter test --no-pub test/roasts/ui_preservation_capture_test.dart test/roasts/ui_preservation_emotion_capture_test.dart --dart-define=CAPTURE_UI_PRESERVATION=true --dart-define=UI_PRESERVATION_PHASE=baseline
flutter test --no-pub test/roasts/ui_preservation_capture_test.dart test/roasts/ui_preservation_emotion_capture_test.dart --dart-define=CAPTURE_UI_PRESERVATION=true --dart-define=UI_PRESERVATION_PHASE=final
```

Use `tool/compare_ui_preservation.py` after final captures for exact decoded-pixel comparison, immutable-image checksum verification and protected-source review. Do not regenerate baseline references to remove failures. The current capture run checked a single weather repository request across Today scrolling and opening/closing its sheets. Broader zero-incremental-request tests are recorded in the implementation verification report.

Reuse the existing `appearance_test`, `forecast_metrics_test`, `forecast_screen_test`, `roasts_screen_test`, `roast_emotion_system_test`, `advanced_roast_reveal_screen_test`, `radar_screen_test`, `radar_refinement_test`, `settings_screen_test`, and meme-sharing tests for behavior. Historical test counts in `docs/ui_implementation` remain historical.

Live radar imagery, actual tile city labels, live animation, native share UI, real-device safe areas, device install, deployment and final production web build identity are not established by fixture screenshots. Baseline capture does not claim any such action. Final build/run details and remaining limitations belong in the final verification report.
