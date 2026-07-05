# DayMaker UI Developer Notes

DayMaker is the polished Flutter UI layer for `grumpy_skies`. It currently runs on local sample data, fallback-aware placeholder assets, and fake repositories so product work can continue before live weather, radar, and share/export services are connected.

## Design System Overview

The DayMaker design system lives in `lib/design/` and should be used before adding one-off styling.

- `dm_colors.dart`: dark atmospheric base colors, glass surfaces, weather accents, alert colors, and opacity helpers.
- `dm_typography.dart`: shared text styles and system font fallback stack.
- `dm_spacing.dart`: page padding, tap targets, icon sizes, and layout gaps.
- `dm_radius.dart`: common border radii for cards, controls, and clipped imagery.
- `dm_shadows.dart`: standard elevation treatments for glass cards and floating surfaces.
- `dm_gradients.dart`: app, storm, twilight, and feature-specific background gradients.
- `dm_motion.dart`: reduced-motion checks and timing constants.
- `dm_theme.dart`: Material 3 theme that wires the tokens into app bars, cards, buttons, inputs, chips, navigation, snackbars, switches, and sliders.

Shared UI primitives live in `lib/shared/widgets/`, including `DmResponsiveScaffold`, `DmAppBackground`, `DmGlassCard`, `DmBottomNav`, `DmHeaderBar`, `DmAssetImage`, buttons, chips, segmented controls, and section headers. Feature screens should compose these pieces instead of recreating card chrome, backgrounds, or responsive wrappers.

## Asset Folder Structure

Assets are declared in `pubspec.yaml` by folder, and typed accessors live in `lib/shared/assets/dm_assets.dart`.

```text
assets/
  backgrounds/
    about/
    forecast/
    fun/
    meme/
    radar/
    reveal/
    roasts/
    settings/
    splash/
  badges/
  brand/
  fun/
  icons/
    controls/
    fun/
    metrics/
    nav/
    settings/
    status/
    weather/
  mascots/
  meme_backgrounds/
  meme_stickers/
  personas/
  radar/
  textures/
```

The app already includes starter files such as `assets/brand/app_icon.png`, `assets/mascots/daymaker_idle.png`, and `assets/personas/karen_roast_queen.png`. Most other paths are intentional placeholders. Missing files render through `DmAssetImage` fallbacks so development builds stay usable while generated art is incomplete.

## Replacing Placeholder Assets

ChatGPT-generated assets should be dropped into the exact paths listed in `DmAssets`. The app code references those paths directly, so keeping names stable avoids code changes.

1. Generate PNG assets at the requested size and transparent/background style for the target slot.
2. Save the file into the matching folder and filename from `lib/shared/assets/dm_assets.dart`.
3. Prefer replacing placeholders in place instead of changing Dart constants.
4. Keep image names lowercase with underscores, for example `assets/personas/frat_bro_barometer_bro.png`.
5. Run `flutter test test/asset_manifest_test.dart` to confirm the manifest still resolves expected folders.
6. Run the full check before handing off: `dart format .`, `flutter analyze`, and `flutter test`.

For backgrounds, use full-bleed PNGs that still work when center-cropped. For icons and small UI art, use transparent PNGs with enough padding to avoid edge clipping. For persona portraits and mascots, keep the subject centered and readable at small card sizes.

## Responsive Layout Rules

Breakpoints are defined in `DMBreakpoints`:

- Compact: widths below `600`.
- Medium: widths from `600` to `1023`.
- Expanded: widths `1024` and up.

Use `DmResponsiveScaffold` for standard pages. It applies page padding, safe areas, background treatment, content centering, and max content widths. The default maximum content widths are unlimited for compact, `840` for medium, and `1180` for expanded.

Use `DMSpacing.pagePaddingForWidth(width)` for manual page padding. Keep scrollable content inside `ListView` or `SingleChildScrollView` with `AlwaysScrollableScrollPhysics` when pull-to-refresh or fixed bottom navigation is present. Expanded layouts may use side-by-side sections, but compact layouts should stack the same content in a readable order.

Do not rely on viewport-scaled font sizes. Use typography tokens, fixed aspect ratios for fixed-format elements such as meme canvases and radar maps, and `FittedBox` or bounded text only where long generated copy could overflow.

## Screen List And Routes

Routes are centralized in `lib/config/app_routes.dart` and wired through `lib/app/daymaker_router.dart`.

| Screen | Route | Notes |
| --- | --- | --- |
| Splash | `/splash` | Initial route and brand entry point. |
| Forecast | `/forecast` | Main weather dashboard and default tab. |
| Roasts | `/roasts` | Persona carousel, featured roast, history, and achievements. |
| Advanced Roast Reveal | `/roasts/reveal` | Nested roast reveal experience. |
| Radar | `/radar` | Provider-ready radar shell with map controls and alert cards. |
| Fun Zone | `/fun` | Achievements, streaks, quizzes, and fun feature entry points. |
| Meme Generator | `/fun/meme` | Nested meme canvas and future export/share workflow. |
| Settings | `/settings` | Preferences and app controls. |
| About | `/settings/about` | Nested about screen. |

Compatibility redirects are also present for `/home`, `/burns`, `/meme-generator`, and `/about`.

## Fake Repository Notes

`lib/main.dart` currently injects `FakeWeatherRepository` and `FakeRoastRepository` through Provider. These implementations read from `DayMakerSampleData` and are intentionally stable for tests, screenshots, UI iteration, and generated asset previews.

- `FakeWeatherRepository` returns a clearly labeled demo weather snapshot and radar alerts for tests/previews.
- `FakeRoastRepository` returns sample personas, roasts, achievements, fun features, and meme templates.
- `DummyWeatherService` implements the older `WeatherApiService` abstraction for randomized demo weather and should not be treated as production data.
- Tests assert repository stability, so keep fake data deterministic unless the tests are updated with the intended behavior.

When live services arrive, add production implementations behind the existing repository interfaces and swap the providers in `main.dart`. Keep fake repositories available for widget tests, previews, and offline development.

## Future Integration Notes

WeatherKit and AccuWeather should connect behind `WeatherApiService` or a production `WeatherRepository`. Normalize provider payloads into `WeatherSnapshot`, `WeatherBundle`, `ForecastHour`, `ForecastDay`, `WeatherMetric`, and `RadarAlert` models before data reaches screens. Keep provider keys, JWT signing, and request secrets outside the Flutter source, preferably in a backend/proxy or secure platform-specific configuration.

RainViewer or another radar provider should replace the painted radar base in `RadarMapPlaceholder`. Keep playback state, layer toggles, and timeline index in the screen/controller layer, then pass resolved tile/frame state into the map widget. Provider frame URLs and any signed requests should be built outside the UI widget.

Share/export should connect in `MemeGeneratorScreen._exportAndShare`. Capture the `RepaintBoundary` keyed by `_canvasKey`, encode the image, and send it to a native share/export service. Forecast roast sharing currently copies text to the clipboard; replace or extend that path with the same share service when native sharing is available.

ChatGPT-generated assets should continue to be treated as static app assets. Generate them outside the app, review them, drop them into the folders above, and let `DmAssetImage` provide graceful fallbacks until every placeholder is replaced.
