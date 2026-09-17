# DayMaker Asset Manifest

Canonical production manifest for generated DayMaker assets. Every required path here must match `lib/shared/assets/dm_assets.dart`, and every parent folder is declared in `pubspec.yaml`.

Generated assets may be absent during development. UI must load these paths only through `DmAssetImage` or `DmSvgIcon` so the app keeps running with fallback visuals.

## Brand

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/brand/app_icon.png` | App icon, about screen | PNG | 1024x1024 px | No |
| `assets/brand/app_icon_foreground.png` | Adaptive app icon foreground | PNG | 1024x1024 px | Yes |
| `assets/brand/logo_mark.png` | Splash, header mark | PNG | 1024x1024 px | Yes |
| `assets/brand/logo_lockup.png` | Splash, about lockup | PNG | 1600x512 px | Yes |
| `assets/brand/wordmark.png` | Splash, about wordmark | PNG | 1600x512 px | Yes |

## Backgrounds

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/backgrounds/splash/day.png` | Splash background, day | PNG | 1440x2560 px | No |
| `assets/backgrounds/splash/night.png` | Splash background, night | PNG | 1440x2560 px | No |
| `assets/backgrounds/splash/storm.png` | Splash background, storm | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/clear_day.png` | Forecast background, clear day | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/clear_night.png` | Forecast background, clear night | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/cloudy.png` | Forecast background, cloudy | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/rain.png` | Forecast background, rain | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/snow.png` | Forecast background, snow | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/storm.png` | Forecast background, storm | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/wind.png` | Forecast background, wind | PNG | 1440x2560 px | No |
| `assets/backgrounds/forecast/fog.png` | Forecast background, fog | PNG | 1440x2560 px | No |
| `assets/backgrounds/roasts/default.png` | Roasts background, default | PNG | 1440x2560 px | No |
| `assets/backgrounds/roasts/morning.png` | Roasts background, morning | PNG | 1440x2560 px | No |
| `assets/backgrounds/roasts/afternoon.png` | Roasts background, afternoon | PNG | 1440x2560 px | No |
| `assets/backgrounds/roasts/night.png` | Roasts background, night | PNG | 1440x2560 px | No |
| `assets/backgrounds/roasts/severe.png` | Roasts background, severe weather | PNG | 1440x2560 px | No |
| `assets/backgrounds/reveal/fog.png` | Roast reveal background, fog | PNG | 1440x2560 px | No |
| `assets/backgrounds/reveal/scratch.png` | Roast reveal background, scratch card | PNG | 1440x2560 px | No |
| `assets/backgrounds/reveal/spotlight.png` | Roast reveal background, spotlight | PNG | 1440x2560 px | No |
| `assets/backgrounds/radar/map.png` | Radar base map background | PNG | 2048x2048 px | No |
| `assets/backgrounds/radar/precipitation.png` | Radar precipitation background layer | PNG | 2048x2048 px | Yes |
| `assets/backgrounds/radar/storm_track.png` | Radar storm track background layer | PNG | 2048x2048 px | Yes |
| `assets/backgrounds/fun/achievements.png` | Fun/progression background | PNG | 1440x2560 px | No |
| `assets/backgrounds/fun/streak.png` | Fun streak background | PNG | 1440x2560 px | No |
| `assets/backgrounds/fun/quiz.png` | Fun quiz background | PNG | 1440x2560 px | No |
| `assets/backgrounds/fun/confetti.png` | Fun celebration background | PNG | 1440x2560 px | Yes |
| `assets/backgrounds/meme/blank_canvas.png` | Meme generator screen background, blank | PNG | 1080x1080 px | No |
| `assets/backgrounds/meme/weather_desk.png` | Meme generator screen background, weather desk | PNG | 1080x1080 px | No |
| `assets/backgrounds/meme/commute.png` | Meme generator screen background, commute | PNG | 1080x1080 px | No |
| `assets/backgrounds/meme/weekend.png` | Meme generator screen background, weekend | PNG | 1080x1080 px | No |
| `assets/backgrounds/settings/default.png` | Settings background, default | PNG | 1440x2560 px | No |
| `assets/backgrounds/settings/account.png` | Settings account background | PNG | 1440x2560 px | No |
| `assets/backgrounds/settings/preferences.png` | Settings preferences background | PNG | 1440x2560 px | No |
| `assets/backgrounds/about/default.png` | About background, default | PNG | 1440x2560 px | No |
| `assets/backgrounds/about/team.png` | About team background | PNG | 1440x2560 px | No |
| `assets/backgrounds/about/version.png` | About version background | PNG | 1440x2560 px | No |

## Mascots And Personas

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/mascots/daymaker_idle.png` | Forecast hero, about screen mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_happy.png` | Splash mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_annoyed.png` | Roast state mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_thinking.png` | Loading/thinking mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_roasting.png` | Roast reveal mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_umbrella.png` | Rain state mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_sleepy.png` | Night/idle mascot | PNG | 1024x1024 px | Yes |
| `assets/mascots/daymaker_severe_alert.png` | Severe weather mascot | PNG | 1024x1024 px | Yes |
| `assets/personas/karen_roast_queen.png` | Persona carousel, roast cards | PNG | 1254x1254 px | No |
| `assets/personas/frat_bro_barometer_bro.png` | Persona carousel, roast cards | PNG | 1042x1068 px | Yes |
| `assets/personas/two_year_old_tiny_thunder.png` | Persona carousel, roast cards | PNG | 1040x1090 px | Yes |
| `assets/personas/politician_spin_doctor.png` | Persona carousel, roast cards | PNG | 1034x1120 px | Yes |
| `assets/personas/grandpa_cloud_historian.png` | Persona carousel, roast cards | PNG | 1022x1102 px | Yes |
| `assets/personas/snarky_storm.png` | Legacy persona carousel | PNG | 1024x1024 px | Yes |
| `assets/personas/cloudy_cynic.png` | Legacy persona carousel | PNG | 1024x1024 px | Yes |
| `assets/personas/sunny_sass.png` | Legacy persona carousel | PNG | 1024x1024 px | Yes |

## Icons

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/icons/nav/home.png` | Navigation icon, home | PNG | 256x256 px | Yes |
| `assets/icons/nav/forecast.png` | Navigation icon, forecast | PNG | 256x256 px | Yes |
| `assets/icons/nav/roasts.png` | Navigation icon, roasts | PNG | 256x256 px | Yes |
| `assets/icons/nav/radar.png` | Navigation icon, radar | PNG | 256x256 px | Yes |
| `assets/icons/nav/fun.png` | Navigation icon, fun | PNG | 256x256 px | Yes |
| `assets/icons/nav/meme.png` | Navigation icon, meme | PNG | 256x256 px | Yes |
| `assets/icons/nav/settings.png` | Navigation icon, settings | PNG | 256x256 px | Yes |
| `assets/icons/nav/about.png` | Navigation icon, about | PNG | 256x256 px | Yes |
| `assets/icons/weather/clear_day.png` | Weather condition icon, clear day | PNG | 256x256 px | Yes |
| `assets/icons/weather/clear_night.png` | Weather condition icon, clear night | PNG | 256x256 px | Yes |
| `assets/icons/weather/partly_cloudy_day.png` | Weather condition icon, partly cloudy day | PNG | 256x256 px | Yes |
| `assets/icons/weather/partly_cloudy_night.png` | Weather condition icon, partly cloudy night | PNG | 256x256 px | Yes |
| `assets/icons/weather/cloudy.png` | Weather condition icon, cloudy | PNG | 256x256 px | Yes |
| `assets/icons/weather/rain.png` | Weather condition icon, rain | PNG | 256x256 px | Yes |
| `assets/icons/weather/drizzle.png` | Weather condition icon, drizzle | PNG | 256x256 px | Yes |
| `assets/icons/weather/thunderstorm.png` | Weather condition icon, thunderstorm | PNG | 256x256 px | Yes |
| `assets/icons/weather/snow.png` | Weather condition icon, snow | PNG | 256x256 px | Yes |
| `assets/icons/weather/sleet.png` | Weather condition icon, sleet | PNG | 256x256 px | Yes |
| `assets/icons/weather/fog.png` | Weather condition icon, fog | PNG | 256x256 px | Yes |
| `assets/icons/weather/wind.png` | Weather condition icon, wind | PNG | 256x256 px | Yes |
| `assets/icons/weather/hail.png` | Weather condition icon, hail | PNG | 256x256 px | Yes |
| `assets/icons/weather/hot.png` | Weather condition icon, hot | PNG | 256x256 px | Yes |
| `assets/icons/weather/cold.png` | Weather condition icon, cold | PNG | 256x256 px | Yes |
| `assets/icons/weather/unknown.png` | Weather condition icon, unknown | PNG | 256x256 px | Yes |
| `assets/icons/metrics/temperature.png` | Metric icon, temperature | PNG | 256x256 px | Yes |
| `assets/icons/metrics/feels_like.png` | Metric icon, feels like | PNG | 256x256 px | Yes |
| `assets/icons/metrics/humidity.png` | Metric icon, humidity | PNG | 256x256 px | Yes |
| `assets/icons/metrics/precipitation.png` | Metric icon, precipitation | PNG | 256x256 px | Yes |
| `assets/icons/metrics/wind.png` | Metric icon, wind | PNG | 256x256 px | Yes |
| `assets/icons/metrics/air_quality.png` | Metric icon, air quality | PNG | 256x256 px | Yes |
| `assets/icons/metrics/pressure.png` | Metric icon, pressure | PNG | 256x256 px | Yes |
| `assets/icons/metrics/visibility.png` | Metric icon, visibility | PNG | 256x256 px | Yes |
| `assets/icons/metrics/uv_index.png` | Metric icon, UV index | PNG | 256x256 px | Yes |
| `assets/icons/metrics/sunrise.png` | Metric icon, sunrise | PNG | 256x256 px | Yes |
| `assets/icons/metrics/sunset.png` | Metric icon, sunset | PNG | 256x256 px | Yes |
| `assets/icons/metrics/moonrise.png` | Metric icon, moonrise | PNG | 256x256 px | Yes |
| `assets/icons/metrics/moonset.png` | Metric icon, moonset | PNG | 256x256 px | Yes |
| `assets/icons/metrics/dew_point.png` | Metric icon, dew point | PNG | 256x256 px | Yes |
| `assets/icons/controls/refresh.png` | Control icon, refresh | PNG | 256x256 px | Yes |
| `assets/icons/controls/share.png` | Control icon, share | PNG | 256x256 px | Yes |
| `assets/icons/controls/save.png` | Control icon, save | PNG | 256x256 px | Yes |
| `assets/icons/controls/close.png` | Control icon, close | PNG | 256x256 px | Yes |
| `assets/icons/controls/back.png` | Control icon, back | PNG | 256x256 px | Yes |
| `assets/icons/controls/search.png` | Control icon, search | PNG | 256x256 px | Yes |
| `assets/icons/controls/location.png` | Control icon, location | PNG | 256x256 px | Yes |
| `assets/icons/controls/play.png` | Control icon, play | PNG | 256x256 px | Yes |
| `assets/icons/controls/pause.png` | Control icon, pause | PNG | 256x256 px | Yes |
| `assets/icons/controls/retry.png` | Control icon, retry | PNG | 256x256 px | Yes |
| `assets/icons/controls/expand.png` | Control icon, expand | PNG | 256x256 px | Yes |
| `assets/icons/controls/collapse.png` | Control icon, collapse | PNG | 256x256 px | Yes |
| `assets/icons/status/success.png` | Status icon, success | PNG | 256x256 px | Yes |
| `assets/icons/status/warning.png` | Status icon, warning | PNG | 256x256 px | Yes |
| `assets/icons/status/error.png` | Status icon, error | PNG | 256x256 px | Yes |
| `assets/icons/status/info.png` | Status icon, info | PNG | 256x256 px | Yes |
| `assets/icons/status/locked.png` | Status icon, locked | PNG | 256x256 px | Yes |
| `assets/icons/status/unlocked.png` | Status icon, unlocked | PNG | 256x256 px | Yes |
| `assets/icons/status/offline.png` | Status icon, offline | PNG | 256x256 px | Yes |
| `assets/icons/status/syncing.png` | Status icon, syncing | PNG | 256x256 px | Yes |
| `assets/icons/fun/dice.png` | Fun icon, dice | PNG | 256x256 px | Yes |
| `assets/icons/fun/streak.png` | Fun icon, streak | PNG | 256x256 px | Yes |
| `assets/icons/fun/trophy.png` | Fun icon, trophy | PNG | 256x256 px | Yes |
| `assets/icons/fun/spark.png` | Fun icon, spark | PNG | 256x256 px | Yes |
| `assets/icons/fun/roast.png` | Fun icon, roast | PNG | 256x256 px | Yes |
| `assets/icons/fun/meme.png` | Fun icon, meme | PNG | 256x256 px | Yes |
| `assets/icons/fun/quiz.png` | Fun icon, quiz | PNG | 256x256 px | Yes |
| `assets/icons/fun/surprise.png` | Fun icon, surprise | PNG | 256x256 px | Yes |
| `assets/icons/settings/persona.png` | Settings icon, persona | PNG | 256x256 px | Yes |
| `assets/icons/settings/units.png` | Settings icon, units | PNG | 256x256 px | Yes |
| `assets/icons/settings/notifications.png` | Settings icon, notifications | PNG | 256x256 px | Yes |
| `assets/icons/settings/location.png` | Settings icon, location | PNG | 256x256 px | Yes |
| `assets/icons/settings/privacy.png` | Settings icon, privacy | PNG | 256x256 px | Yes |
| `assets/icons/settings/about.png` | Settings icon, about | PNG | 256x256 px | Yes |
| `assets/icons/settings/theme.png` | Settings icon, theme | PNG | 256x256 px | Yes |

## Badges And Fun Illustrations

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/badges/first_roast.png` | Badge art, first roast | PNG | 512x512 px | Yes |
| `assets/badges/week_streak.png` | Badge art, week streak | PNG | 512x512 px | Yes |
| `assets/badges/month_streak.png` | Badge art, month streak | PNG | 512x512 px | Yes |
| `assets/badges/all_day_roasts.png` | Badge art, all-day roasts | PNG | 512x512 px | Yes |
| `assets/badges/severe_weather.png` | Badge art, severe weather | PNG | 512x512 px | Yes |
| `assets/badges/social_roaster.png` | Badge art, social roaster | PNG | 512x512 px | Yes |
| `assets/badges/karen_mode.png` | Badge art, Karen mode | PNG | 512x512 px | Yes |
| `assets/badges/persona_switcher.png` | Badge art, persona switcher | PNG | 512x512 px | Yes |
| `assets/badges/level_five.png` | Badge art, level five | PNG | 512x512 px | Yes |
| `assets/badges/legendary_roaster.png` | Badge art, legendary roaster | PNG | 512x512 px | Yes |
| `assets/fun/empty_state.png` | Fun illustration, empty state | PNG | 1200x900 px | Yes |
| `assets/fun/no_weather.png` | Fun illustration, no weather | PNG | 1200x900 px | Yes |
| `assets/fun/pull_to_refresh.png` | Fun illustration, pull to refresh | PNG | 1200x900 px | Yes |
| `assets/fun/achievement_unlocked.png` | Fun illustration, achievement unlocked | PNG | 1200x900 px | Yes |
| `assets/fun/streak_celebration.png` | Fun illustration, streak celebration | PNG | 1200x900 px | Yes |
| `assets/fun/weather_quiz.png` | Fun illustration, weather quiz | PNG | 1200x900 px | Yes |
| `assets/fun/roast_history.png` | Fun illustration, roast history | PNG | 1200x900 px | Yes |
| `assets/fun/share_prompt.png` | Fun illustration, share prompt | PNG | 1200x900 px | Yes |
| `assets/fun/crazy_day_wheel.png` | Fun illustration, Crazy Day Predictor wheel | PNG | 1024x1024 px | Yes |

## Meme Assets

The Weather Meme Studio uses the following shipped artwork. The former sunny/rainy/office preset filenames are legacy references, not required studio runtime assets. Flutter renders captions and watermarks; captioned reference PNGs are not bundled. The complete catalog, authoring notes, and verification commands are described in [`docs/WEATHER_MEME_STUDIO.md`](docs/WEATHER_MEME_STUDIO.md).

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/meme_backgrounds/storm_boss_cat.webp` | Storm Boss Cat, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/storm_boss_cat.webp` | Storm Boss Cat, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/tiny_umbrella_big_storm.webp` | Tiny Umbrella, Big Storm, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/tiny_umbrella_big_storm.webp` | Tiny Umbrella, Big Storm, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/forecast_betrayal.webp` | Forecast Betrayal, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/forecast_betrayal.webp` | Forecast Betrayal, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/sun_is_personal.webp` | Sun Is Personal, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/sun_is_personal.webp` | Sun Is Personal, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/wind_left_the_chat.webp` | Wind Left the Chat, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/wind_left_the_chat.webp` | Wind Left the Chat, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/fog_buffering.webp` | Fog Buffering, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/fog_buffering.webp` | Fog Buffering, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/forecast_roulette.webp` | Forecast Roulette, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/forecast_roulette.webp` | Forecast Roulette, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/snow_day_victory.webp` | Snow Day Victory, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/snow_day_victory.webp` | Snow Day Victory, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/humidity_volume.webp` | Humidity Volume, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/humidity_volume.webp` | Humidity Volume, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/cloud_side_eye.webp` | Cloud Side-Eye, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/cloud_side_eye.webp` | Cloud Side-Eye, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/sidewalk_preheating.webp` | Sidewalk Preheating, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/sidewalk_preheating.webp` | Sidewalk Preheating, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/monday_drizzle.webp` | Monday Drizzle, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/monday_drizzle.webp` | Monday Drizzle, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/rainbow_plot_twist.webp` | Rainbow Plot Twist, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/rainbow_plot_twist.webp` | Rainbow Plot Twist, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/pollen_boss_battle.webp` | Pollen Boss Battle, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/pollen_boss_battle.webp` | Pollen Boss Battle, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_backgrounds/temperature_whiplash.webp` | Temperature Whiplash, editable background | WebP | 1080x1080 px | No |
| `assets/meme_thumbnails/temperature_whiplash.webp` | Temperature Whiplash, library thumbnail | WebP | 288x288 px | No |
| `assets/meme_stickers/side_eye_cloud.png` | Side Eye Cloud, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/smug_sun.png` | Smug Sun, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/rain_drop.png` | Rain Drop, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/lightning_bolt.png` | Lightning Bolt, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/tiny_umbrella.png` | Tiny Umbrella, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/snowflake.png` | Snowflake, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/wind_swoosh.png` | Wind Swoosh, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/coffee_cup.png` | Coffee Cup, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/sunglasses.png` | Sunglasses, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/pollen_orb.png` | Pollen Orb, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/rainbow.png` | Rainbow, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/loading_ring.png` | Loading Ring, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/sparkle.png` | Sparkle, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/wet_sock.png` | Wet Sock, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/melting_popsicle.png` | Melting Popsicle, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/party_cloud.png` | Party Cloud, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/thermometer.png` | Thermometer, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/flying_hat.png` | Flying Hat, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/splash.png` | Splash, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/hot_toast.png` | Hot Toast, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/speech_bubble.png` | Speech Bubble, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/thought_bubble.png` | Thought Bubble, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/tissue_box.png` | Tissue Box, movable sticker | PNG | 512x512 px | Yes |
| `assets/meme_stickers/cloud_heart.png` | Cloud Heart, movable sticker | PNG | 512x512 px | Yes |

| Required content/font path | Usage |
| --- | --- |
| `assets/meme_content/weather_meme_catalog.v1.json` | 15 templates, safe-text zones, 90 template pairs and 50 persona pairs. |
| `assets/meme_content/weather_stickers.v1.json` | 24 stable sticker IDs and provenance. |
| `assets/meme_content/weather_meme_catalog.v1.schema.json` | Starter catalog schema; distinct from editor document schema. |
| `assets/fonts/Nunito.ttf` | Locally bundled `MemeSans` font; license retained alongside. |
| `assets/fonts/SpaceMono-Bold.ttf` | Locally bundled `MemeMono` font; license retained alongside. |

All 39 SVG sources and provenance are retained under `docs/meme-assets/` for authoring, outside the runtime asset bundle. Asset IDs and paths can remain stable when replacing the explicitly labeled placeholder illustrations.

## Radar And Textures

| Required asset path | Screen usage | Format | Expected dimensions | Transparent background required |
| --- | --- | --- | --- | --- |
| `assets/radar/precipitation_light.png` | Radar overlay, light precipitation | PNG | 2048x2048 px | Yes |
| `assets/radar/precipitation_moderate.png` | Radar overlay, moderate precipitation | PNG | 2048x2048 px | Yes |
| `assets/radar/precipitation_heavy.png` | Radar overlay, heavy precipitation | PNG | 2048x2048 px | Yes |
| `assets/radar/storm_cells.png` | Radar overlay, storm cells | PNG | 2048x2048 px | Yes |
| `assets/radar/lightning.png` | Radar overlay, lightning | PNG | 2048x2048 px | Yes |
| `assets/radar/wind_flow.png` | Radar overlay, wind flow | PNG | 2048x2048 px | Yes |
| `assets/radar/watch_area.png` | Radar overlay, watch area | PNG | 2048x2048 px | Yes |
| `assets/radar/warning_area.png` | Radar overlay, warning area | PNG | 2048x2048 px | Yes |
| `assets/textures/paper_grain.png` | Overlay texture, paper grain | PNG | 1024x1024 px | Yes |
| `assets/textures/fog_noise.png` | Overlay texture, fog noise | PNG | 1024x1024 px | Yes |
| `assets/textures/rain_streaks.png` | Overlay texture, rain streaks | PNG | 1024x1024 px | Yes |
| `assets/textures/frost.png` | Overlay texture, frost | PNG | 1024x1024 px | Yes |
| `assets/textures/heat_haze.png` | Overlay texture, heat haze | PNG | 1024x1024 px | Yes |
| `assets/textures/card_grain.png` | Overlay texture, card grain | PNG | 1024x1024 px | Yes |
| `assets/textures/scratch_mask.png` | Reveal texture, scratch mask | PNG | 1024x1024 px | Yes |
| `assets/textures/vignette.png` | Overlay texture, vignette | PNG | 1024x1024 px | Yes |
