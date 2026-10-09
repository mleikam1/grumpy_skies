# Acceptance results — current refinement, October 9, 2026

This ledger covers the local follow-up to `d259422`. The prior implementation's 426 passing tests, push to `origin/main`, and iPhone installation do not establish delivery of these new changes. Those earlier results remain archived in [PRIOR_ACCEPTANCE_RESULTS.md](refinement/PRIOR_ACCEPTANCE_RESULTS.md).

**Current status:** source and artwork are implemented; the final 480-test suite, analyzer, formatting, production-browser and controlled visual checks pass. Web release, Android debug and iOS simulator builds pass. The user has authorized delivery to `origin/main`; physical-iPhone installation of this refinement is not included.

## Verification ledger

| Check | Current result | Evidence |
| --- | --- | --- |
| Final post-fix full suite | PASS: 480 tests | [Full test log](refinement/logs/final-tests.txt) |
| Final analyzer | PASS: no issues, 4.8 seconds | [Analyzer log](refinement/logs/final-analyze.txt) |
| Final formatting | PASS: 252 files, zero changed | [Format log](refinement/logs/final-format.txt) |
| Final emotion card/gallery capture run | PASS: 10 checks, 20 images | [Capture log](refinement/logs/final-emotion-capture.txt), [screenshots](refinement/screenshots/) |
| Focused forecast/readability tests | PASS: 35 checks at the recorded forecast checkpoint | [Forecast report](refinement/FORECAST_REFINEMENT.md) |
| Focused radar tests | PASS: 13 checks | [Radar report](refinement/RADAR.md) |
| Persona asset completeness | PASS: 50/50, 50 unique hashes, all native RGBA, complete provenance, exact source-byte equality | [Verification](artwork/emotions/verification.json), [per-file metadata](artwork/emotions/emotion_asset_metadata.json) |
| Web release | PASS: compiled production entrypoint | [Build log](refinement/logs/build-web.txt) |
| Android debug APK | PASS: debug APK | [Build log](refinement/logs/build-android.txt) |
| iOS simulator debug | PASS: unsigned simulator application | [Build log](refinement/logs/build-ios-simulator.txt) |
| Current physical-iPhone installation | NOT PERFORMED | Earlier `d259422` installation remains separate |
| Live forecast and NOAA MRMS | PASS at capture time; actual browser weather and radar playback | [Live browser QA](refinement/LIVE_BROWSER_QA.md), [backend health](refinement/radar_evidence/backend_health.json) |
| Live OpenWeather global/futurecast radar | OWNER ACTION: upstream 401 / key rejected | [Backend health](refinement/radar_evidence/backend_health.json) |

The first current-refinement full run passed 472 checks. An expanded asset test subsequently failed because it assumed many pixels had alpha exactly 255; generated artwork is predominantly nearly opaque. The corrected assertion requires more than 100,000 visible pixels with alpha at least 250, along with transparency, native dimensions, unique hashes and bundled loading. PNG bytes were not changed to satisfy the test. The subsequent 478-test run passed. A final review then found fixed-height clipping in the hourly unavailable state at 200% text; the content now grows, two theme regressions were added, and the final post-fix run passed all 480 tests.

## Behavior and visual evidence

[Live app overview](refinement/live-overview.jpg) and [live browser notes](refinement/LIVE_BROWSER_QA.md) cover the actual production `lib/main.dart` entrypoint at a 390 × 844 viewport, using the existing backend and a manual public-city search for Overland Park. No personal coordinates or device-location permission were needed.

- Today loaded real weather. Details retained real values, correct units/location timezone, readable labels and grouped event cards. Unsupported UV/AQI, missing moon times and absent last-hour precipitation displayed unavailable.
- The seven-day sheet opened above the bottom navigation, scrolled to Thursday and kept long conditions readable. Light/Dark capture pairs document the same flow.
- The map displayed actual OSM cartography without the prior CARTO watermark. NOAA frames came through the existing radar API. Play changed to Pause and advanced the frame label; playback was then paused. Local dry imagery was not replaced with invented precipitation.
- Switching Light to Dark retained the current weather, Karen quote and expression. The Settings Light/Dark/System model remains in place; automated state/persistence and system-mode behavior are part of regression coverage.
- Live selection of all five personas showed corresponding artwork and mood labels. Roasts displayed the explicit Complaining expression and badge with the real local editorial quote. Share showed that exact text, and Make a meme opened the existing studio with the same bottom caption. No external social message was sent.

The `live_*.jpg` files are browser screenshots, including the debug ribbon. `after_*.png`, canonical emotion cards and expression galleries are real-widget captures using clearly identified controlled fixtures. The seven-day stress fixture tests long conditions and 200% text; it is not a live forecast. Radar evidence separates a real, single visible OSM/NOAA viewport from simulated unavailable cases. See [forecast before/after evidence](refinement/FORECAST_REFINEMENT.md), [radar evidence](refinement/RADAR.md) and [emotion behavior](refinement/EMOTION_SYSTEM.md).

Automated coverage includes metric text contrast ≥4.5:1 and icon contrast ≥3:1, narrow/large-text layouts, reachable daily/hourly content, modal navigation blocking and close controls, real-data/unavailable persistence, deterministic mood precedence/inference, legacy CSV/JSON compatibility, persona aliases and same-persona fallback, exact snapshot handoff, and real weather/radar behavior. Existing settings, navigation, alert/ad guards, meme storage/editor/export and accessibility regressions remain in the full suite. This is not manual VoiceOver/TalkBack certification.

## Asset acceptance

All five personas have all ten requested mood files. The 50 native PNGs are 1086 × 1448 RGBA and total 62,955,894 bytes. Every selected output was individually inspected, then reviewed on light/dark comparison sheets at 128 × 171 portrait slots. Karen complaining, Frat Bro hyped, Grandpa cozy and toddler excited follow the supplied reference poses. Frat Bro cozy was revised to make it distinguishable from happy at that size.

Tiny exterior colored pixels and edge fringes remain at native resolution, especially Karen's pink/white edge and toddler shirt-bottom cyan. They are less apparent at card size. No clean-matte or exact-original claim is made; no local pixel cleanup was performed. The existing approved/legacy paths remain unchanged. [ASSET_STATUS.md](ASSET_STATUS.md) and [asset evidence](artwork/emotions/README.md) record all sources, prompts, dimensions, checks and limitations.

## Commands and remaining limits

Commands recorded in the focused reports:

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub test/radar_refinement_test.dart test/radar_screen_test.dart
flutter test --no-pub test/forecast_refinement_capture_test.dart --dart-define=CAPTURE_FORECAST_REFINEMENT=true
python3 docs/ui_implementation/artwork/emotions/build_emotion_qa.py
```

The [final execution record](refinement/logs/final-results.json) records exact arguments, timestamps and successful exit codes for formatting, analysis, the full suite, and all three builds. All builds use the existing public production backend:

```sh
flutter build web --release --no-pub --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
flutter build apk --debug --no-pub --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
flutter build ios --simulator --debug --no-codesign --no-pub --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
flutter test --no-pub test/roast_emotion_capture_test.dart --dart-define=CAPTURE_EMOTIONS=true --reporter expanded
dart run tool/build_roast_pack.dart --output work/roast-pack-review.json
flutter run --no-pub -d web-server -t lib/main.dart --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api --web-hostname 127.0.0.1 --web-port 8766
```

Toolchain: Flutter 3.44.4 / Dart 3.12.2. Android reports the existing future Kotlin migration warnings; iOS reports existing CocoaPods integration and App Store version/build metadata warnings. These builds do not establish store-release readiness. Windows/Linux builds were not run; this repository has no macOS target. Read-only screenshot composition ran with bundled Pillow Python at `/Users/MattLeikam/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/compose_refinement_review.py`.

Two isolated dark card captures were refreshed after the bulk capture showed transient missing text in its raster output. No application code or artwork changed; the refreshed toddler and Grandpa captures display their labels and actions correctly. Logs: [toddler](refinement/logs/toddler-capture-refresh.txt), [Grandpa](refinement/logs/grandpa-capture-refresh.txt).

The [changed-file inventory](refinement/CHANGED_FILES.md) covers this follow-up.

The owner must repair OpenWeather radar key/entitlement server-side for global/futurecast modes. NOAA and forecast success do not resolve that separate authorization error. The optional splash mascot fallback is pre-existing; native sharing/Photos delivery and current physical-device behavior remain unverified. No signing, bundle ID, deployed backend credentials, store settings, app data or saved document schema changed. This follow-up adds `url_launcher: 6.3.2` and its required platform packages for attribution links; existing dependency versions were not upgraded.
