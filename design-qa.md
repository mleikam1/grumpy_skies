# Radar cleanup design QA

final result: passed

Reviewed against all three supplied approved PNGs. The references specify composition; illustrative weather, values, palette, and map details are not product data.

## Evidence

- Reference-size renders: 427 × 922 logical pixels, captured at 2×. Side-by-side images compare each approved state with the actual production RadarScreen inside DaymakerShell at that same logical size.
- Additional captures: 390 × 844, 320 × 740 at 100% and 200% text, 768 × 1024, and 844 × 390, each in light and dark themes. Safe areas are included. The narrow and short layouts use an explicitly scrollable dock with permanent map actions and attribution.
- Those deterministic captures use fixture metadata and transparent tiles, never a generated map or invented precipitation. Adjacent evidence JSON identifies this boundary. They prove control layout, time formatting, and state transitions, not current weather coverage.
- Real runtime evidence: final production web build at http://127.0.0.1:8901/radar in the in-app browser at 1280 × 720; native production app in the existing iOS simulator. Actual OSM cartography renders in both. Native NOAA history, playback starting at the oldest frame, pause, expansion, and return were exercised. Light and dark native basemaps were visually inspected. The original simulator appearance was restored.
- Three native screenshots and the combined radar-ios-overview.png show normal Live Radar, FutureCast, and Expanded Map. Live FutureCast currently reports missing provider access. The available FutureCast timeline is covered by explicitly identified deterministic captures.

## Findings resolved

1. Repeated floating playback, Latest badges, tall sheet, and permanent zoom toolbar were consolidated into one dock plus Recenter and Layers. The ordinary dock was tightened by sharing the timeline touch region with its tick labels; each main control retains a comfortable target.
2. Expanded Map preserves the same FlutterMap state and controller. The normal header, optional Chaos chip, and navigation disappear; Done remains reachable. Expansion does not move the camera or reload metadata.
3. Initial large-text and landscape renders obscured map actions. The actions now reflow horizontally; short landscape separates header/actions from the dock. A visible scrollbar exposes overflowed dock content. Touch tests scroll to the actual timeline, scrub a real fixture frame, and open Details.
4. The first expanded header placed Done adjacent to the mode label. Done now aligns to the right. Native safe areas remain respected.
5. Accessible activation was restored for outer semantic controls. The timeline announces the selected valid instant and meaningful next/previous timestamps. Escape dismisses a sheet before exiting expansion.
6. Initial map readiness now explicitly enables Recenter/Zoom. Background work is gated before initialization and during teardown; hidden metadata completions do not trigger rendering. Health failures survive hide/show and rapid mode return without another request.
7. Timing uses actual provider frame instants, separate metadata refresh completion, and selected-location timezone handling, including DST repetition. Missing forecast issue time is stated rather than invented. An old observation retains its real age after a fresh metadata download.

8. Final review found keyboard scrubbing could get stuck between sparse frames. Arrow keys now step actual frame indices; Home/End select endpoints. A shell-owned lazy RadarSession now retains mode-specific selection across Today/PlanCast/Fun tab changes while stopping hidden timers. It starts no work before the first Radar visit.
9. Final accessibility review found the hidden Chaos chip lacked its promised Details fallback. Details now reuses the same existing explanation for current usable weather, with no score on historical or forecast frames.

## Intentional differences from the illustrations

- Current safe-area insets and the existing bottom navigation are retained. Their footprint can differ from the reference artwork.
- Chaos uses the existing algorithm and a distinct signal icon, and appears only for usable current weather on the latest observation. At extreme text sizes/short landscape, its explanation stays in Details so map actions remain reachable.
- The NOAA RGB service and exact US FutureCast product do not expose a verified quantitative palette. Their compact provider-guide labels replace the illustrative Light–Heavy gradient. Global OpenWeather uses its separately verified discrete dBZ bins. Provider colors in actual tiles are not altered.
- Forecast and observation times, cities, history range, score, and status differ legitimately with the data. No screenshot's example weather is hardcoded.
- At 320 px and 200% text, readable labels and reachable controls take priority over the ordinary-phone visible-map target. The dock scrolls, while Expand remains available for more map space.

## Main implementation files

| Component | Responsibility |
| --- | --- |
| `lib/features/radar/radar_screen.dart` | Normal/expanded arrangements, panels, local opacity, lifecycle and current Chaos gating |
| `lib/features/radar/radar_session.dart` | One lazy shell-owned timeline controller retained across primary tabs |
| `lib/features/radar/radar_playback_controller.dart` | Per-mode selections, pause/play, real-frame reconciliation, refresh and bounded warmup |
| `lib/features/radar/radar_presentation.dart` | Valid-time, age, timezone/DST and real timeline ticks |
| `lib/features/radar/widgets/radar_control_dock.dart` | Shared touch, keyboard and accessible playback controls |
| `lib/features/radar/widgets/open_weather_radar_map.dart` | Persistent map, current-frame layer, guarded loading/health, opacity and linked credits |
| `lib/features/radar/widgets/radar_color_scale.dart` | Source-correct scale or provider-guide affordance |
| `lib/app/daymaker_shell.dart` | Expanded navigation footprint and lazy session ownership |

## State and request evidence

One map owner, one shared RadarPlaybackController, and one playback timer are used. The existing 900 ms cadence, one-minute metadata refresh interval, bounded next-two-frame health warmup, HTTP caching, provider endpoints, and backend behavior remain intact. Twenty expand/collapse cycles preserved camera, selection, mode, opacity, and playing state. Metadata counts stayed 1→1 in Live and 2→2 after entering FutureCast. Three repeated panel cycles did not change any recorded backend count. The test weather repository received zero extra reads. Ordinary renderer tile requests after camera/viewport/frame changes are outside that fixture counter.

## Verification results

- Full Flutter suite: 892 tests passed. The final Chaos Details fallback received an additional 15-test responsive capture/control regression pass after that full-suite run.
- Focused state/time/map/control suite: 56 tests passed before the final health regression was added; that regression subsequently passed in the full suite.
- Responsive capture/control suites: 30 tests passed, including touch access to scrolled controls at 200% text and in landscape. Final captures include keyboard/session changes; the constrained-layout regression additionally checks that current Chaos remains accessible through Details while historical frames omit it.
- Flutter analysis: no issues found, including the final Chaos Details fallback.
- Formatting and git diff whitespace checks: passed.
- Final web release and iOS simulator debug builds: passed. Both final artifacts were launched and their three states captured. Browser warning/error log was empty.
- No physical iPhone install, Android-device exercise, merge, push, backend deployment, or store submission is included in this local task.

## Live-provider limits

Native and final browser NOAA metadata/history loaded successfully for Chicago. The browser's Overland Park request returned a temporary NOAA metadata failure, and its explicit unavailable UI was checked. OpenWeather US FutureCast access is absent on the current provider account; therefore live future precipitation imagery is not verified. No colorful precipitation episode was available for visual contrast inspection; the unchanged provider tile palette and overlay-opacity path are covered in code/tests, with real quiet-map contrast checked in both themes.

The inherited backend may return a transparent HTTP-200 fallback tile with a response header. The stock image decoder cannot expose that header. Existing selected-location health checks and actual decode/network failures surface known unavailability, but a fallback only in a remote panned tile can evade the location probe. The UI makes no claim that missing imagery confirms clear weather. See docs/radar_cleanup/provider_audit.md for the exact boundary.

## Handoff artifacts

- Local browser preview: http://127.0.0.1:8901/radar
- `radar-ios-overview.png` — three final native runtime states.
- `after/ios-live.png`, `after/ios-futurecast.png`, `after/ios-expanded.png` — full native captures.
- `comparison-live.png`, `comparison-futurecast.png`, `comparison-expanded.png` — approved reference versus production widgets with fixture metadata and omitted tiles.
- `after/light_large_text_controls_scrolled.png` and `after/dark_large_text_controls_scrolled.png` — reachable controls at 200% text.
- `after/request-state-proof.json` — state and request-count assertions.
- `provider_audit.md` — provider metadata, attribution, palette and inherited fallback boundaries.
- `verification.json` — actual commands, results and baseline commit.
