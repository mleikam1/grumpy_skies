# DayMaker appearance architecture

Implemented in the existing app; no alternate production entrypoint.

## Preference and startup

`AppAppearance` supplies Light / Dark / System. `UserSettings.appearance` defaults to Light. The existing `SharedPreferencesSettingsRepository` stores the canonical string in `settings.appearance`, preserving unrelated keys and all existing settings. On load it accepts known legacy string keys (`settings.themeMode`, `themeMode`, `theme_mode`, `appearance`) and boolean keys (`settings.darkMode`, `darkMode`, `isDarkMode`). The canonical valid value takes precedence. Unknown values fall back safely; legacy keys are not removed.

`main.dart` already awaited `SettingsController.loadSettings()` before `runApp`; this ordering is retained. `DaymakerApp` supplies separate `DMTheme.lightTheme` and `darkTheme`, and the saved `themeMode` on its first Flutter frame. System follows platform brightness only while selected. This does not claim that native launch art or a browser's initial HTML paint has been tested for saved-mode parity.

The Settings Appearance selector updates optimistically. Settings writes are serialized and rapid changes coalesce into the latest complete immutable settings snapshot, avoiding older writes completing last. Save failures stay visible and offer a retry; a `false` result from preferences is treated as a failure. No preference change resets a repository, router, persona, location or draft store.

## Tokens and presentation

`DMSemanticColors` is a `ThemeExtension` based on the approved token file. It owns application/card/navigation surfaces, primary/secondary/muted text, borders/dividers, focus, hero/persona gradients, actions, template tiles and shadows. `BuildContext.dmColors` resolves it. `DMTheme` maps these roles into `ColorScheme` and Material buttons, inputs, chips, sheets, dialogs, menus, snackbars, navigation, tooltips, sliders, switches and text selection.

The bundled Roboto font uses the UI-only `DaymakerSans` family; the existing Nunito `MemeSans` remains available to persisted meme captions. No runtime font download was added. The raster reference does not identify its original font; Roboto is an approximation selected after capture review. Light and Dark share type sizes, weights, spacing and shapes. Theme animation is 180ms, or zero under reduced motion. System status/navigation bar icon contrast follows effective UI brightness through the app's `AnnotatedRegion` and AppBar theme.

Settings, About, privacy dialog, licenses and welcome screens consume semantic surfaces. Settings cards expand for their text rather than imposing title/subtitle line limits. The notification control continues to save the existing preference, but explicitly states that delivery is not available in this build. It does not pretend to schedule notifications.

Character art, actual weather day/night icons and the user's meme document colors are intentionally not theme tokens. A theme change must not recolor those pixels or reinterpret weather state. Existing shared components and feature migrations consume the same semantic API.

## Verification performed

- `flutter test --no-pub test/appearance_test.dart test/settings_screen_test.dart test/about_screen_test.dart`: **25 passed**.
- Appearance tests cover fresh-install Light; seven legacy preference forms; canonical precedence; malformed values; unrelated data preservation; serialized rapid writes; error/retry; safe completion after disposal; all three actual Settings choices; first-frame saved Dark; live System brightness; explicit mode override; reduced motion; mounted route/subtree/scroll/editable-draft retention.
- Derived Settings/About/welcome widget layouts run in both modes at 320, 360, 390, 430, 768 and 1440 logical widths. The 320 case uses 200% text scaling. These checks detect Flutter layout exceptions; they are not screenshot fidelity proofs.
- Token tests check at least 4.5:1 contrast for primary, secondary and muted text against card surfaces and for primary-action text. They do not prove every image/gradient composite.
- Scoped `flutter analyze --no-pub` for design, settings controller/repository/model, Settings/welcome, app and new appearance tests: **no issues**.

Screenshot evidence, whole-app live-data behavior and platform builds are recorded separately in the acceptance report. The state-retention test uses a mounted route with an editable field; actual meme recovery/export is covered by the existing meme suite and requires its own validation.

## Roasts state integration

Production now supplies `PackRoastRepository` in `main.dart`. It loads the existing local editorial pack, receives an actual weather bundle, selects by persona/weather/unit, excludes recently selected lines before allowing repeats, and records session history only when a line is displayed. Static catalog methods retain the existing feature/template definitions; no sample weather enters the production roast-selection path.

The Roasts screen reuses `WeatherLocationController.currentWeather`, which is exposed only for the selected location. A direct link without a current bundle requests weather once through the existing `WeatherRepository`; missing location/data shows a truthful state. Known mismatched coordinates are rejected. Dependency/theme changes do not repeat this request, reload roasts, or reset selection. Another roast uses the local pack. Temperature-unit changes intentionally rerender local pack values while reusing weather.

Selection IDs and aliases remain unchanged. The five approved portraits use the common artwork component in both themes. Sharing freezes the exact displayed quote and weather at display time; Copy, the native share sheet, and Make a meme consume that frozen value. Clipboard failures are reported; opening/dismissing native share never produces a fabricated success message. Official active alerts suppress the roast card and actions and link to weather safety details. Existing reveal access remains below the approved composition.

`flutter test --no-pub test/roasts_screen_test.dart test/appearance_test.dart test/settings_screen_test.dart test/about_screen_test.dart`: **32 passed** after the Roasts integration. The seven Roasts tests cover approved fixture composition; persisted persona selection; exact Copy and meme handoff; one production weather fetch across appearance changes and Another; missing-location and active-alert behavior; both appearances at 320/360/390/430/768/1440 widths with 320 at 200%; and local pack unit formatting/anti-repeat/displayed-history semantics. A later scoped analysis including the Roasts files is clean. These are fixture and widget checks, not a live service or native share-sheet verification.

## Reveal cleanup and shared share action

The reveal route accepts an optional `DisplayedRoastSnapshot` extra and otherwise freezes the latest registry choice once on entry. It never synthesizes a roast or location, requests weather, reselects content on theme/registry updates, or claims XP/streak/achievement rewards. An empty entry links to Roasts; active official warnings replace the reveal with a safety message. The card still supports tap and drag, and now has a real keyboard/screen-reader Reveal/Hide button. Zero XP omits the badge. Reduced motion sets the existing switcher's duration to zero.

Roasts and reveal share `showDisplayedRoastShareSheet`: Copy/native Share/Make a meme all consume the same frozen snapshot. The native platform sheet additionally uses the existing monetization operation guard until completion because it is not a Navigator modal. The existing router modal observers are unchanged. Template and document query parameters for the meme route remain intact.

`flutter test --no-pub test/advanced_roast_reveal_screen_test.dart test/roasts_screen_test.dart`: **14 passed**. Reveal coverage includes missing source, route-extra precedence, registry/theme immutability, tap/drag/keyboard reveal, reduced motion, exact Copy/meme handoff, arriving-warning suppression, zero-reward behavior and both appearances across the six supported test widths (320 at 200%). Native platform share UI is not claimed verified by these widget tests.
