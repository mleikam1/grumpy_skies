# DayMaker implementation handoff

The approved Light/Dark UI is implemented in the existing Flutter app on branch `feat/approved-daymaker-light-dark`. The implementation was prepared in the user-confirmed checkout below. A subsequent user request authorized committing and pushing it to origin/main, preserving the remote d984b28 upload commit:

`/Users/MattLeikam/Documents/Codex/2026-09-17/files-pasted-by-the-user-work/outputs/grumpy_skies`

The implementation uses the existing Provider/router/weather/cache/radar/meme/monetization architecture. Light is the default, Light/Dark/System persists, the four tabs are Today/Radar/Roasts/Fun, and Settings opens from the gear. All five persona IDs/aliases and legacy assets remain. Roasts now uses actual weather and the local editorial pack; exact displayed text reaches sharing and the meme editor. Fun's local tabs and four new layered templates work, with existing activities below the approved fold.

**Validation:** 426 tests pass; analyzer clean; 239 Dart files format clean; 46 fixture capture checks pass. Web release, Android debug and iOS simulator builds pass. See the command-level ledger in [ACCEPTANCE_RESULTS.md](ACCEPTANCE_RESULTS.md), build logs and [visual review](VISUAL_QA.md). Actual browser interaction verified Dark switching, navigation, caption editing, and rendered PNG export. Native save/share and completed browser-download delivery are not claimed.

**Remaining:** reconstruction details and alpha edges still differ from the approved raster; global radar tiles currently fail upstream authorization despite a working forecast service. The repository has no macOS target. Existing native build warnings/version metadata and signed-device/store validation remain owner work. The old optional Predictor wheel PNG still uses its fallback. This is not an exact or production-approved visual match.

## Review evidence

- [Six primary app captures](primary-overview.png), with synthetic fixture values clearly separated from live checks.
- `screenshots/fixture/`: primary, secondary, error/offline, editor/export, responsive and reduced-motion captures.
- `comparisons/`: six reference/candidate side-by-side, overlay, difference and transform records; supplied helper output for Today.
- [Asset provenance and remaining defects](ASSET_STATUS.md), `artwork/character_comparisons.png` and `artwork/runtime_slot_checks.png`.
- [Appearance architecture and state tests](THEME_ARCHITECTURE.md), [baseline](BASELINE.md), [progress](PROGRESS.md), [preview instructions](PREVIEW.md).

## Run locally

From the existing checkout:

```sh
flutter run -d web-server -t lib/main_preview.dart --web-hostname 127.0.0.1 --web-port 8765
```

The explicit preview uses real screen widgets with memory-only fixture dependencies; it cannot modify production weather/cache/settings/meme data. The running review URL is `http://127.0.0.1:8765` while its local server remains active.

For the actual production entrypoint on a chosen emulator/simulator:

```sh
flutter devices
flutter run -d <emulator-or-simulator-id> -t lib/main.dart
```

For production web on a plain local server without the hosting `/api` rewrite:

```sh
flutter run -d chrome -t lib/main.dart --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
```

This endpoint is the existing app's configured public backend, not a new service. Provider authorization must be repaired server-side by the owner for radar. Do not paste keys into the client.

Reproduce verification:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --dart-define=CAPTURE_APPROVED_UI=true test/approved_preview_capture_test.dart
python3 tools/compare_approved_ui.py
```

The comparison script requires Pillow; use the bundled Python described in PREVIEW.md if system Python lacks it.

## Data, dependencies and rollback

No packages were upgraded and the lockfile is unchanged. The UI adds bundled Roboto as DaymakerSans; legacy MemeSans/MemeMono remain for documents. New art lives under assets/approved_v1, with old paths retained. Appearance adds settings.appearance and reads known legacy preferences; it does not delete old keys. The document schema is unchanged and all 19 templates use the existing editor.

The baseline is bedddc8 on feat/weather-first-ad-monetization. For comparison, use a separate checkout of that revision without clearing device data. A full rollback to the older app must retain support for approved_v1 assets/reference validation if users have saved new-template documents; otherwise the old validator cannot read those new references. UI/theme rollback should preserve that compatibility seam and the documents themselves.

At the initial handoff, the changes were local and uncommitted. The user subsequently authorized a commit and push to origin/main. No deployment, store submission, billing change or data reset was performed. Source changes and validation evidence are included in this implementation commit.
