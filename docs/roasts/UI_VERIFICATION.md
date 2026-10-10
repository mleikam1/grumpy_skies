# UI preservation verification

The final capture run passed **16 tests** and all **74 final PNGs are byte-identical** to their immutable baselines: zero differing pixels, no masks and no changed references. `ui_evidence/comparison_final3.json` is the latest machine-readable comparison. The `final3` captures include all final safety/history/lifecycle corrections and preserve the earlier `final` and `final2` runs separately. `final3/source_at_capture_start.json` records the exact 285 protected working-tree hashes; **none changed during capture**. `final3/protected-source.diff` records their complete diff against the clean starting HEAD. `UI_BASELINE.md` contains the authoritative-source record and the important capture chronology/input limitation.

## Scope actually verified

The real Forecast, Roasts, Radar, Fun and Settings screen classes and DaymakerShell were rendered with fixed test dependencies, not preview screens. Both themes passed at 390×844, 320×844 / 200% text, and 820×1180. This includes Today/roast views, hourly/daily modal composition and accessible close control, Roasts persona/featured composition, the Radar offline state, Fun/meme entry, and appearance controls. Separate card captures cover all five personas and all ten expressions in both themes.

Two additional tests passed for the long selected city “San Fernando del Valle de Catamarca, Catamarca, Argentina” and a long quote at 320 / 200% in both themes. They assert that actual header/footer/quote paragraphs do not exceed max lines and no layout exception occurs. No production presentation changes were needed.

The new capture/stress/support files pass scoped static analysis with no issues. Existing appearance, forecast metrics/refinement, radar/refinement, settings and ten persona long-quote tests also passed in the first combined run (67 passes; two existing test contracts failed after the engine changes and were reported to the implementation owner for repair). This does not label those two failures pre-existing; they were caused by changed builder/wrapper contracts. After compatibility repairs, `flutter test --no-pub test/roast_emotion_system_test.dart` passed **17/17** in this session, including both formerly failing cases. The other 52 tests from the combined run had already passed; these are separate run results, not an invented single rerun count.

## Protected-file review

Of 285 protected source/artwork entries, only these ten paths differ:

| File | Reason for change |
| --- | --- |
| `lib/main.dart` | Creates one shared local roast controller, durable pack cache, and debug-only inspector registration; retains the production entrypoint and providers for weather/settings/safety/ads. |
| `lib/features/forecast/forecast_screen.dart` | Replaces the screen-local selector with the shared controller; forwards the immutable selection into the existing snapshot/card and commits exposure after display. Widget composition is unchanged. A stable PageStorageKey now isolates alert ExpansionTile expansion state from the enclosing forecast scroll offset, fixing a reproduced double-to-bool crash when an alert appears after scrolling; this changes state identity only. |
| `lib/features/roasts/roasts_screen.dart` | Reuses current weather and local selections on context changes, forwards selection provenance, commits displayed history, and supports sharing a history snapshot. Widget composition is unchanged. |
| `lib/features/fun/meme/meme_weather.dart` | Adds deep-immutable selection provenance, a bounded persisted snapshot history in the existing registry, and excludes unknown weather facts from frozen values. Exact original history handoffs survive restart. No display-state replacement. |
| `lib/features/fun/meme/meme_studio.dart` | Copies the existing chosen snapshot provenance with its exact caption/weather into the saved document. No editor layout change. |
| `lib/features/fun/meme/models/meme_document.dart` | Adds bounded optional `roastSnapshot` data with backward-compatible parsing/serialization. Existing documents remain readable and no document is reset. |
| `lib/features/roasts/advanced_roast_reveal_screen.dart` | Reuses the existing safety-state layout to suppress frozen humor when hazardous conditions or unverified-alert restrictions apply. Safety copy no longer implies an official alert when none exists. |
| `lib/features/roasts/services/displayed_roast_share.dart` | Rechecks the same pure safety gate before opening/acting on a frozen handoff; no selection or network request. |
| `pubspec.yaml` and `pubspec.lock` | Add timezone 0.10.1 for selected-location IANA/DST rules. Existing icon package versions are unchanged. |

All protected artwork bytes, shared components, theme tokens, routing/shell files, forecast tiles/sheets, persona-card widgets, radar implementation and settings presentation match the clean starting revision. No files were restored from a historical design, no settings or drafts were cleared, and no golden baseline was regenerated to pass a comparison. New source files outside the protection manifest implement the data layer and are covered by the main verification report.

Safety corrections also prevent hidden Today cards from counting as displayed exposures, revalidate Roasts locally on a minute tick/resume, compare snapshot selection identity and keep history keyed to its exact original selection/weather. Those changes have no effect on the controlled normal-state pixels. The review identified and the implementation owner repaired these issues before `final3` capture.

The old preview test had assumed a humidity complaint for its synthetic weather. Its Today assertion now expects the same context-free line recorded in the new baseline, without changing fixture weather or golden files. The 18 existing 390×930 preview route tests passed after that assertion update; they are additional compatibility checks, not the production-widget baseline.

## Reproduce

```sh
flutter test --no-pub test/roasts/ui_preservation_capture_test.dart test/roasts/ui_preservation_emotion_capture_test.dart --dart-define=CAPTURE_UI_PRESERVATION=true --dart-define=UI_PRESERVATION_PHASE=final3
python3 tool/compare_ui_preservation.py --phase final3
flutter test --no-pub test/roasts/ui_preservation_stress_test.dart
flutter analyze --no-pub test/roasts/ui_preservation_capture_test.dart test/roasts/ui_preservation_emotion_capture_test.dart test/roasts/ui_preservation_stress_test.dart test/roasts/support
```

The comparison tool uses standard-library PNG decoding if encoded bytes differ. Exact encoded equality proves exact pixel equality without decoding. It verifies baseline checksums first and reports every protected source change; it never modifies baseline images.

The final capture runtime was Flutter 3.44.4 stable (`ad70ec4617`) / Dart 3.12.2, at pixel ratio 1. The final protected source record remained unchanged during the entire capture run. Later formatting changed the raw Forecast/Roasts hashes only: exact captured sources were reconstructed and formatted in scratch, producing byte-identical current sources. See `ui_evidence/final3/post_capture_format_review.json`; the original hashes and screenshots were not altered.

## Limits

This is a controlled presentation-preservation pass, not a live-provider or physical-device sign-off. Radar has frozen transparent tiles and its real unavailable-state controls; city-label readability with live map tiles and active live NOAA imagery are not established by this run. Live icon animation, native platform share UI, physical safe areas, physical-device installation, and deployment are not claimed here. The filled hourly/daily icon request remains pending because the authoritative source still specifies line icons. Hourly/daily/commute/weekend humor placement remains pending because no approved inline slots exist. Main build/run identity, network accounting and independent deployment status are documented by the implementation owner.
