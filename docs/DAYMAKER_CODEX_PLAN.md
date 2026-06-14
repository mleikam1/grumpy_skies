# DayMaker Flutter Architecture And Codex Plan

This plan guides Codex implementation after the documentation pass. Do not implement Flutter UI until the user requests it.

## Architecture Goals

- One adaptive Flutter app for iOS, Android, tablet, and web.
- Shared design tokens and reusable components before screen-specific styling.
- Clear separation between weather data, personality logic, asset resolution, and UI.
- Compile cleanly before final generated artwork exists.
- Production-focused error, loading, empty, stale, permission-denied, and offline states.

## Recommended App Shape

Current project direction already includes `pages`, `widgets`, `services`, `repositories`, and feature folders. Continue evolving toward feature-first modules while preserving simple imports where practical.

Recommended structure:

```text
lib/
  app.dart
  main.dart
  config/
    app_routes.dart
    daymaker_breakpoints.dart
  core/
    assets/
      daymaker_asset_resolver.dart
      fallback_asset.dart
    theme/
      daymaker_colors.dart
      daymaker_spacing.dart
      daymaker_text.dart
      daymaker_motion.dart
      daymaker_theme.dart
    widgets/
      daymaker_scaffold.dart
      adaptive_content_shell.dart
      empty_state.dart
      loading_state.dart
  features/
    weather/
      models/
      repositories/
      services/
      widgets/
    personas/
      models/
      services/
      widgets/
    radar/
    memes/
    progression/
    settings/
  pages/
```

This does not require a large refactor all at once. Move code only when a feature needs the shared boundary.

## State Management

The current app uses `provider`, which is appropriate for the first production pass.

Use:

- `ChangeNotifier` for settings, user preferences, and UI state that changes often.
- Plain services for deterministic logic, such as roast generation and asset lookup.
- Repositories for weather data, caching, and future API integration.
- Immutable models for weather, personas, achievements, and meme templates.

Avoid:

- Screen-local hard-coded weather values except in test fixtures or dummy services.
- Business logic embedded in widgets.
- Asset paths scattered across screens.

## Design Tokens

Create token files before major UI work:

- Color tokens for weather conditions, alert levels, persona categories, surfaces, text, and borders.
- Spacing tokens for 4, 8, 12, 16, 24, 32, and 48 pixel rhythm.
- Radius tokens for small, medium, full, and sheet/modal use.
- Text roles for display, title, body, label, numeral, and caption.
- Motion durations and curves.
- Breakpoints for phone, compact tablet, large tablet, and web.

Screens should consume theme extensions or shared token helpers rather than raw colors and arbitrary spacing.

## Shared Components

Implement shared components before polishing individual screens:

- `DayMakerScaffold`: common app shell, background slot, safe areas, adaptive nav.
- `AdaptiveContentShell`: responsive max width, columns, and scroll behavior.
- `FallbackAsset`: centralized missing-image UI.
- `WeatherHero`: current conditions without baked art text.
- `ForecastCard`: reusable forecast module frame.
- `MetricChip`: weather metric display.
- `PersonaCard`: persona art, state, and selection.
- `RoastBubble`: Flutter-rendered roast copy.
- `RadarControlBar`: timeline, layer, and opacity controls.
- `MemeCanvasPreview`: Flutter text overlays on generated backgrounds.
- `SettingsSection`: accessible settings grouping.
- `AchievementBadge`: locked and unlocked badge display.

## Asset Resolution Plan

Use a centralized resolver so screens never directly assume final asset files exist.

Resolver responsibilities:

- Return a typed asset reference for a screen, condition, persona, or badge.
- Check whether an asset is declared and available.
- Provide a fallback widget or fallback token style.
- Support light mode, dark mode, breakpoint, and weather condition variants.
- Keep generated-art usage separate from dynamic text and data.

Pseudo-interface:

```dart
enum DayMakerAssetKind { background, persona, badge, feature, memeBackground, radarOverlay }

class DayMakerAssetRequest {
  const DayMakerAssetRequest({
    required this.kind,
    required this.id,
    this.condition,
    this.brightness,
    this.breakpoint,
  });
}
```

## Weather Data Plan

Keep the existing repository/service boundary.

Near-term:

- Continue using `DummyWeatherService` for deterministic app development.
- Expand models only as screens need them.
- Add stale/offline metadata to repository results.
- Add tests for conversion, caching, and fallback states.

Future:

- Swap dummy service with real provider such as WeatherKit or another weather API.
- Gate location access behind clear permission flows.
- Cache the last successful forecast.
- Separate severe weather alerts from playful copy.

## Personality And Roast Plan

Personality should be data-driven enough to tune without editing every screen.

Model:

- Persona id.
- Display name.
- Tone tags.
- Intensity range.
- Weather affinities.
- Safety behavior.
- Unlock or premium state.
- Asset references.

Roasts:

- Generated by service logic or template banks.
- Always Flutter-rendered text.
- Never embedded in artwork.
- Suppressed or toned down for severe weather, emergencies, or user preference.

## Adaptive UI Plan

Use one code path with responsive layout decisions:

- Phone: bottom navigation, single-column scrolling, compact controls.
- Tablet: optional side rail, two-column content, larger radar/meme canvas.
- Web: centered max-width content, keyboard focus, hover states, scroll restoration.

Do not fork the app into separate mobile and web screens unless a platform API requires it.

## Testing Plan

Minimum test coverage:

- Widget smoke tests for every primary screen.
- Component tests for missing asset fallbacks.
- Weather repository tests for cache and dummy data.
- Settings controller tests for units, intensity, theme, and notification preferences.
- Persona roast tests for severe weather tone suppression.
- Golden tests for shared components once design tokens stabilize.

CI should run:

- `flutter analyze`
- `flutter test`
- Optional `flutter test --update-goldens` only by explicit request.

## Codex Implementation Order

1. Documentation foundation: keep these docs current as product decisions change.
2. Token foundation: add DayMaker theme extensions, breakpoints, spacing, typography, and condition colors.
3. Asset resolver: add typed asset lookup with placeholders and no dependency on final generated images.
4. Shared app shell: build adaptive scaffold, navigation, and content shell.
5. Weather model pass: stabilize dummy data, repository states, and formatting utilities.
6. Today Dashboard: implement the main weather experience first.
7. Forecast Timeline: implement hourly and daily scan views.
8. Persona Roasts and Persona Closet: implement personality system with adjustable intensity.
9. Radar: implement placeholder map and overlay controls, then connect real layers later.
10. Meme Maker: implement Flutter-rendered meme canvas and share/export flow.
11. Progression: implement achievements, streaks, and badge fallbacks.
12. Settings: implement units, theme, accessibility, notifications, privacy, and about/legal entry points.
13. Asset swap pass: add generated art through the resolver after UI compiles with placeholders.
14. Polish and QA: accessibility, reduced motion, responsive layouts, performance, and tests.

## Codex Working Rules

- Read `AGENTS.md` and all DayMaker docs before UI work.
- Make small, verifiable changes.
- Prefer existing project dependencies unless a new dependency clearly reduces risk.
- Keep generated art separate from dynamic Flutter UI.
- Do not commit large generated assets without explicit user direction.
- Do not block app compilation on missing final assets.
- Run relevant Flutter analysis and tests after implementation changes.
