# Today details and forecast sheets

## Evidence and diagnosis

Reviewed the approved light/dark boards, existing Today captures, and supplied iOS screenshots `references/details-before.jpg`, `metrics-before.jpg`, and `seven-day-before.jpg`. Reproduced the original metric contrast and modal navigation problems through the real Today preview route before editing. The before captures are retained in `screenshots/before_{light,dark}_{details,daily_sheet}.png`.

`DmMetricChip` painted `DMGradients.glassNavy` in both themes while its text inherited light-theme dark ink. The generic forecast modal used the nested shell navigator, leaving bottom navigation above the modal. Its generic `ListTile` composition gave long condition text and temperature values competing horizontal space.

## Changes

- Introduced `DMMetricColors`: surface, border, value, label, status, unavailable, and icon-accent roles, derived from the app theme. Light metrics use white cards and dark ink; Dark uses the approved navy surface and light ink. Muted unavailable text retains normal-text contrast rather than disabled opacity.
- Rain, AQI, and Feels like form a compact summary. Detail cards use a two-column atmosphere grid, a full-width last-hour amount, and a separate Sun & moon group. Cards grow with content and switch to one column at large text sizes. No metric label, value, or status is ellipsized.
- Both daily and hourly sheets now use the root navigator, safe areas, a draggable height, a fixed title/close header, and an independently scrollable content area. Daily conditions wrap on their own row; high/low values stay grouped and have an explicit accessibility label. Daily count remains the actual available count, up to seven. The hourly insight uses the same sheet surface and scrolling behavior.
- Empty/error hourly cards grow to fit provider messages instead of inheriting the fixed tile height; a real One Call access error is covered at 320 points and 200% text in both themes.
- Inline daily rows gain vertical breathing room. Hourly tiles widen with system text size, preserving readable time and temperature. The precipitation explanation wraps and the provider footer has deliberate spacing and semantic secondary text.

## Data behavior

- Actual sun/moon event timestamps are formatted using the selected weather location's UTC offset. A missing event remains unavailable, using the existing epoch sentinel pattern, instead of inventing sunrise/sunset/moonrise/moonset times. This also applies to snapshot adapters and missing persisted event fields; existing real timestamps are untouched.
- Missing provider UV no longer becomes `0 Low` (or a fabricated persisted default of 5): a negative sentinel renders `Unavailable`. Known zero UV is still a valid value. Existing observed values and times remain unchanged.
- The repository snapshot now carries the current AQI/category; it no longer synthesizes `0 Live`. Unsupported AQI displays unavailable. Zero with a genuine category remains valid.
- Visibility keeps imperial miles and uses kilometres for metric weather. Pressure and precipitation values retain their supplied values/units.
- No storage reset, weather refetch on theme change, navigation destination change, or new network request was added.

## Validation

35 focused tests passed across `forecast_metrics_test.dart`, `forecast_screen_test.dart`, `weather_trust_test.dart`, and `forecast_refinement_capture_test.dart`.

The new tests cover metric text contrast >= 4.5:1 and icon contrast >= 3:1 in both themes, real values/timezone/units, missing-data persistence, unsupported AQI, 320-point layout at 2x text, all seven days reachable at 2x text, untruncated long conditions, closing daily/hourly sheets, and the app navigation being blocked while the modal is open. The real-route captures assert a single weather request throughout viewing details and opening the daily sheet.

Capture command:

```sh
flutter test --no-pub test/forecast_refinement_capture_test.dart --dart-define=CAPTURE_FORECAST_REFINEMENT=true
```

Visually inspected light/dark details and daily sheets and normal/2x long-condition seven-day captures. `after_{light,dark}_details`, `after_{light,dark}_metrics`, and `after_{light,dark}_daily_sheet` use the actual Today screen with the explicitly synthetic approved preview fixture (three available days). The `after_{light,dark}_{normal,large_text}_seven_day_{sheet,bottom}` and `hourly_sheet` captures use the real forecast widgets with an explicitly labeled seven-day stress fixture. These images are UI QA evidence, not live provider weather. Before images are preserved; recapture defaults only write after images.
