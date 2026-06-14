# DayMaker Master Asset Manifest

This manifest defines planned art needs for the 9 DayMaker screens. It is a production planning document, not a requirement that every asset exists before UI work begins.

## Global Asset Rules

- Flutter renders all real UI, including text, buttons, cards, navigation, toggles, inputs, sliders, chips, lists, layout, and dynamic weather values.
- Generated artwork is limited to backgrounds, mascots, personas, badges, feature illustrations, meme backgrounds, radar overlays, and decorative art.
- Do not bake forecast data, roast text, timestamps, locations, settings labels, or navigation labels into images.
- Every asset must have a graceful fallback so the app compiles and runs before final images are available.
- Prefer transparent PNG, WebP, Lottie/Rive, or Flutter-native drawing depending on the asset. Keep SVGs for simple vector marks and icons only when they fit the existing app pipeline.
- Store generated source prompts and final filenames together so assets can be regenerated consistently.

## Proposed Asset Roots

- `assets/images/backgrounds/`
- `assets/images/personas/`
- `assets/images/mascots/`
- `assets/images/badges/`
- `assets/images/features/`
- `assets/images/memes/`
- `assets/images/radar/`
- `assets/animation/`

The Flutter app should declare asset directories only after they exist or after placeholder files are added. Until then, use resolver fallbacks.

## Naming Conventions

Use lowercase snake case:

- Backgrounds: `bg_<screen>_<condition>_<aspect>.<ext>`
- Personas: `persona_<id>_<pose>.<ext>`
- Badges: `badge_<id>_<state>.<ext>`
- Meme backgrounds: `meme_bg_<id>_<aspect>.<ext>`
- Radar overlays: `radar_overlay_<condition>_<density>.<ext>`
- Feature art: `feature_<screen>_<concept>.<ext>`

Aspect suffixes:

- `phone_portrait`
- `phone_landscape`
- `tablet`
- `wide`

## Fallback Requirements

Every screen should work with:

- No background art.
- No persona art.
- No badge art.
- No animation files.
- No remote weather data.

Fallback behavior:

- Backgrounds: token-driven gradient or solid surface.
- Personas and mascots: Flutter-rendered avatar placeholder with persona color and initials.
- Badges: simple Flutter icon badge with locked/unlocked state.
- Meme backgrounds: neutral template with user-selected weather mood color.
- Radar overlays: color-coded Flutter layer with opacity controls.

## Screen Asset Manifest

### 1. Splash / Launch

Purpose: Establish the DayMaker brand quickly while the app initializes.

Assets:

- `bg_splash_clear_phone_portrait`
- `bg_splash_clear_tablet`
- `feature_splash_daymaker_mark`
- Optional short loading animation in `assets/animation/splash_weather_loop.*`

Art notes:

- No loading text or app version in artwork.
- Leave center-safe space for Flutter-rendered logo and status copy.
- Must also work as a static image when animation is disabled.

Fallback:

- Token gradient background with Flutter-rendered DayMaker wordmark.

### 2. Today Dashboard

Purpose: Show current conditions, key decisions, and a personality summary.

Assets:

- `bg_today_clear_phone_portrait`
- `bg_today_rain_phone_portrait`
- `bg_today_storm_phone_portrait`
- `bg_today_snow_phone_portrait`
- `bg_today_clear_tablet`
- `persona_default_weather_companion_neutral`
- `feature_today_weather_window`

Art notes:

- Backgrounds should express condition and time of day without containing weather numbers.
- Keep top and center areas readable for Flutter-rendered current weather UI.

Fallback:

- Weather-condition gradient selected from design tokens.

### 3. Forecast Timeline

Purpose: Let users scan hourly and daily forecast changes.

Assets:

- `bg_forecast_soft_grid_phone_portrait`
- `feature_forecast_timeline_clouds`
- `feature_forecast_empty_state`

Art notes:

- Do not draw chart axes, hour labels, temperatures, precipitation values, or daily labels in images.
- Decorative timeline art should sit behind Flutter-rendered charts and rows.

Fallback:

- Neutral surface with Flutter-rendered divider and placeholder shimmer.

### 4. Persona Roasts

Purpose: Let users choose or receive personality-driven weather commentary.

Assets:

- `persona_sunny_hype_neutral`
- `persona_sunny_hype_excited`
- `persona_storm_sage_neutral`
- `persona_storm_sage_warning`
- `persona_cozy_cloud_neutral`
- `persona_dramatic_front_neutral`
- `bg_roasts_stage_phone_portrait`
- `feature_roasts_reveal_fog`

Art notes:

- Persona art can show expression and mood, but all roast copy must be Flutter text.
- Persona names, labels, intensity, and unlock state must not be baked into portraits.

Fallback:

- Persona cards use token color, initials, and Flutter iconography.

### 5. Radar

Purpose: Show precipitation and weather movement with playful context.

Assets:

- `radar_overlay_rain_light`
- `radar_overlay_rain_heavy`
- `radar_overlay_storm_cells`
- `radar_overlay_snow`
- `bg_radar_map_neutral`
- `feature_radar_empty_state`

Art notes:

- Radar overlays can be decorative or mock overlays until real map layers are connected.
- Do not bake map labels, timestamps, storm warnings, location names, or playhead values into images.

Fallback:

- Flutter-rendered map placeholder with animated or static overlay layer.

### 6. Meme Maker

Purpose: Generate shareable weather memes from user-selected templates and live conditions.

Assets:

- `meme_bg_clear_sassy_square`
- `meme_bg_rain_dramatic_square`
- `meme_bg_heat_meltdown_square`
- `meme_bg_snow_cozy_square`
- `meme_bg_storm_alert_square`
- `feature_meme_empty_state`

Art notes:

- Meme background images must contain no text.
- Flutter renders all meme captions, temperatures, locations, timestamps, stickers, and share controls.

Fallback:

- Solid or gradient meme canvas with selectable weather mood swatches.

### 7. Persona Closet

Purpose: Manage personas, mood intensity, voice packs, and favorites.

Assets:

- `bg_personas_closet_phone_portrait`
- Persona portraits from the shared persona set.
- `feature_personas_locked_state`
- `feature_personas_selected_state`

Art notes:

- Art should support card-based selection but not include selection rings, names, chips, or lock labels.
- Flutter owns unlock messaging and persona metadata.

Fallback:

- Flutter-rendered persona avatars and badge overlays.

### 8. Progression And Badges

Purpose: Reward streaks, forecast checks, shares, and exploration.

Assets:

- `badge_first_forecast_locked`
- `badge_first_forecast_unlocked`
- `badge_rain_ready_locked`
- `badge_rain_ready_unlocked`
- `badge_heat_hero_locked`
- `badge_heat_hero_unlocked`
- `badge_streak_week_locked`
- `badge_streak_week_unlocked`
- `bg_progression_trophy_shelf_phone_portrait`

Art notes:

- Badge art should not include badge names or progress numbers.
- Flutter renders all progress, dates, descriptions, and achievement copy.

Fallback:

- Flutter icon badge grid with locked/unlocked tokens.

### 9. Settings

Purpose: Control units, notifications, privacy, persona intensity, accessibility, theme, and account preferences.

Assets:

- `feature_settings_weather_controls`
- `feature_settings_notifications`
- Optional decorative background `bg_settings_soft_pattern`

Art notes:

- Do not put labels like Fahrenheit, Celsius, Notifications, Privacy, or About in artwork.
- Settings must remain usable with no art.

Fallback:

- Plain token surfaces and Flutter-rendered section icons.

## Cross-Screen Persona Set

Initial persona candidates:

- Sunny Hype: optimistic, high-energy, positive spin.
- Storm Sage: calm, safety-aware, grounded in risk.
- Cozy Cloud: gentle, soft, low-roast comfort.
- Dramatic Front: theatrical, high-roast entertainment.
- Practical Pal: direct, concise, commute-focused.

Each persona should support:

- Neutral pose.
- Happy or celebratory pose.
- Concerned or alert pose.
- Small avatar crop.
- Full card portrait.

All persona metadata, names, descriptions, and settings are Flutter-rendered.

## Asset Production Checklist

For each generated asset, record:

- Filename.
- Screen or component owner.
- Prompt.
- Aspect ratio and size.
- Transparent or opaque background.
- Light/dark mode suitability.
- Safe text overlay zones.
- Fallback behavior.
- Licensing and source notes.
- Compression target.

Do not block feature implementation on final art. Build with placeholders first, then swap assets through the resolver.
