# Local preview and capture

The normal application entrypoint remains `lib/main.dart`. The explicit
`lib/main_preview.dart` entrypoint composes the **same screen widgets** with
synthetic, memory-only dependencies. It is not a replacement UI or a production
weather fallback. Production code does not import either preview library.

From the checkout root:

```sh
flutter run -d chrome -t lib/main_preview.dart
flutter run -d chrome -t lib/main_preview.dart --dart-define=PREVIEW_DARK=true --dart-define=PREVIEW_ROUTE=/roasts
flutter run -d chrome -t lib/main_preview.dart --dart-define=PREVIEW_ROUTE=/fun
```

`PREVIEW_ROUTE` also accepts `/radar`, `/settings`, `/settings/about`,
`/roasts/reveal`, `/fun/meme`, and `/splash`. Appearance controls remain interactive
and save to memory only. Each launch starts a fresh state. Today selects Karen;
an independent Roasts launch selects Grandpa, matching the approved fixture.

The preview registers no ad, telemetry, persistent cache, or progression service.
Weather and roast repositories are local fixture adapters, settings use
`InMemorySettingsRepository`, meme documents use `MemoryMemeBackend`, and the
backend HTTP client rejects all requests. Radar therefore exercises its real
unavailable state, with transparent in-memory tiles that perform no network or
disk-cache access; its fixture screenshot is not evidence of live radar service.
Native lost-photo recovery is disabled only in preview composition, so it cannot
consume a pending real image-picker result. Normal production recovery is intact.

Fixture values come from `docs/daymaker_exact_ui/fixtures/approved_design_fixture.json`.
The fixed clock is Monday, October 12, 2026 at 10:00 AM in Chicago. The domain
model requires additional wind, humidity, UV, AQI, and progression fields that the
board does not supply: zero values are explicitly synthetic adapters. Additional
persona quotes are synthetic test copy. The fixture has only three daily records,
so truthful forecast length takes precedence over the concept's seven-day label.

Capture the app's own rendered pixels with Flutter:

```sh
flutter test --no-pub --dart-define=CAPTURE_APPROVED_UI=true test/approved_preview_capture_test.dart
```

Normal test runs do not write screenshots. The opt-in command writes under
`docs/ui_implementation/screenshots/fixture/`. Each primary screenshot uses a
fresh session, 390×930 logical viewport, text scale 1.0, and 2× rasterization
(780×1860 PNG). The light Today app-focused reference is 340×812; its ratio gives
390×931.4. The shared 930-pixel height is an explicit equivalent viewport, not a
device frame or mock status bar. The app reserves its own navigation space.
Actual registered fonts and bundled artwork are loaded before rendering.
Font registrations are loaded once per test process so repeated cases do not
invalidate the renderer's font caches.

The test also exercises 320, 360, 430, 768, and 1440 logical widths, plus 1.35×
text and the reduced-motion media preference. Secondary captures include Settings,
About, Radar unavailable, roast reveal, onboarding, location prompt, weather error,
offline weather, meme library, editor and internal PNG export preview. The export
test renders a PNG but never presses Save Image or Share. Captures kept after a
failure are diagnostic images; a PNG alone does not
mean its assertion passed. Final acceptance results record the successful run.

Use the supplied comparison helper on equivalent image regions. It permits only
uniform candidate scaling. Small reference crop differences between the three
screens require explicitly recorded crops; never stretch the candidate to match.
Source concept pixels are references, not pixel-perfect Flutter goldens.

```sh
python3 tools/compare_approved_ui.py
```

This additional diagnostic retains the complete reference and app content,
uniformly scales each to 390 pixels wide, and pads the shorter canvas in gray.
It writes six side-by-side/overlay/difference sets and a JSON transform record in
`docs/ui_implementation/comparisons/`. The source dark crops have a shorter aspect
ratio than the canonical light UI; their padding is recorded rather than hidden
by distortion. The helper requires Pillow (available in the Codex bundled Python).

On this Mac, system Python lacks Pillow. The installed bundled interpreter can run the comparison command without installing packages:

```sh
/Users/MattLeikam/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/compare_approved_ui.py
```
