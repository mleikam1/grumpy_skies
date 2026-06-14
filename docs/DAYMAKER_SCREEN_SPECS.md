# DayMaker Screen-By-Screen Specs

These specs define the first production target for DayMaker's 9 primary screens. They are UI implementation guidance only; do not implement until requested.

## Global Screen Rules

- Flutter renders all text, values, controls, navigation, lists, cards, and layout.
- Artwork may appear behind, beside, or within UI but must not contain dynamic weather data or labels.
- Every screen needs loading, empty, offline/stale, missing-asset, permission-denied, and error states where applicable.
- Every screen must adapt across iOS, Android, tablet, and web from one code path.
- Severe weather and safety information must be clear, serious, and accessible.
- Placeholder assets are expected until final generated artwork is added.

## 1. Splash / Launch

Primary job:

- Initialize services and route the user to the right starting state.

Core content:

- Flutter-rendered DayMaker brand.
- Loading state.
- Optional short status line for first launch or offline restore.

Interactions:

- No required user action.
- Respect reduced motion.

States:

- First launch.
- Returning user.
- Offline with cached weather.
- Initialization error with retry.

Adaptive notes:

- Center brand and status on phone.
- Use wider background crop on tablet and web.

Asset usage:

- Background or loading animation only. No baked text.

## 2. Today Dashboard

Primary job:

- Answer "What is my day going to feel like, and what should I do about it?"

Core content:

- Location.
- Current temperature and condition.
- Feels-like temperature.
- High and low.
- Precipitation chance.
- Wind, humidity, UV, and alert chips.
- Personality summary.
- Next best action, such as bring a jacket, hydrate, or expect rain.

Interactions:

- Pull or button refresh.
- Unit display follows settings.
- Tap metric chips for detail.
- Tap persona summary to open roasts.
- Tap alerts for safety details.

States:

- Loading current weather.
- Fresh data.
- Stale cached data.
- Location permission needed.
- Weather service unavailable.
- Severe weather alert.

Adaptive notes:

- Phone: hero weather stack followed by cards.
- Tablet: hero plus side column of decision cards.
- Web: centered dashboard with optional multi-column modules.

Asset usage:

- Condition background and optional mascot/persona art. All values and copy are Flutter text.

## 3. Forecast Timeline

Primary job:

- Help users understand when weather changes over the next hours and days.

Core content:

- Hourly forecast.
- Daily forecast.
- Precipitation timeline.
- Temperature curve.
- Wind and UV highlights.
- Sunrise and sunset if available.

Interactions:

- Toggle hourly/daily sections.
- Scrub timeline.
- Expand a day.
- Switch between temperature, rain, wind, and UV layers.

States:

- Loading forecast.
- Partial data.
- Empty provider response.
- Offline cached forecast.
- Unit conversion.

Adaptive notes:

- Phone: horizontal hourly scroller and vertical daily list.
- Tablet/web: chart and daily list can sit side by side.

Asset usage:

- Decorative background or empty-state illustration only. Charts, labels, and data points are Flutter-rendered.

## 4. Persona Roasts

Primary job:

- Deliver weather commentary through selectable DayMaker personalities.

Core content:

- Current persona.
- Roast or encouragement text.
- Weather context.
- Intensity control.
- Extra roasts or refresh action.
- Safety-aware messaging when needed.

Interactions:

- Change persona.
- Adjust intensity.
- Reveal extra roast.
- Save favorite line.
- Share to Meme Maker.

States:

- No persona selected.
- Persona locked.
- Roast loading.
- Severe weather tone suppression.
- Offline template fallback.

Adaptive notes:

- Phone: persona carousel over roast card.
- Tablet/web: persona list beside roast stage.

Asset usage:

- Persona portraits, reveal fog, and stage art only. Roast text is Flutter-rendered.

## 5. Radar

Primary job:

- Show where weather is moving and give users confidence about timing.

Core content:

- Map or placeholder map.
- Precipitation overlay.
- Timeline/playhead.
- Layer controls.
- Location marker.
- Last updated time.
- Alert boundaries if available.

Interactions:

- Pan and zoom map where supported.
- Play/pause radar loop.
- Scrub timeline.
- Toggle layers.
- Adjust overlay opacity.
- Recenter location.

States:

- Map unavailable.
- Location permission denied.
- Radar data loading.
- No precipitation nearby.
- Stale radar data.
- Severe alert active.

Adaptive notes:

- Phone: full-height map with compact bottom controls.
- Tablet/web: larger map with persistent side controls.

Asset usage:

- Decorative radar overlays and map placeholder. Map labels, timestamps, and controls remain Flutter-rendered.

## 6. Meme Maker

Primary job:

- Let users create shareable weather memes from current conditions and persona copy.

Core content:

- Canvas preview.
- Background selector.
- Text fields or generated caption slots.
- Weather value tokens.
- Persona/sticker selector.
- Share and save controls.

Interactions:

- Choose background.
- Edit caption.
- Insert current weather tokens.
- Move or resize Flutter-rendered text overlays.
- Export image.
- Share through platform sheet.

States:

- No weather data.
- Missing meme background.
- Export success.
- Export failure.
- Share unavailable on platform.

Adaptive notes:

- Phone: canvas first, controls below.
- Tablet/web: canvas beside editor controls.

Asset usage:

- Textless meme backgrounds and decorative stickers. Captions, weather values, locations, and timestamps are Flutter-rendered.

## 7. Persona Closet

Primary job:

- Let users manage DayMaker personalities and tone preferences.

Core content:

- Persona grid/list.
- Selected persona details.
- Tone and intensity preview.
- Favorites.
- Locked/unlocked state.
- Premium or future expansion hooks if applicable.

Interactions:

- Select persona.
- Preview sample line.
- Favorite persona.
- Adjust default intensity.
- Open unlock criteria.

States:

- No personas loaded.
- Locked persona.
- Asset missing.
- Settings save failure.

Adaptive notes:

- Phone: grid with detail sheet.
- Tablet/web: grid plus persistent detail panel.

Asset usage:

- Persona portraits and decorative closet background. Names, descriptions, locks, and controls are Flutter-rendered.

## 8. Progression And Badges

Primary job:

- Reward daily use, preparedness, and exploration without distracting from weather utility.

Core content:

- Current streak.
- XP or progress summary.
- Badge grid.
- Recent unlocks.
- Next achievable goal.
- Weather-readiness milestones.

Interactions:

- Tap badge for details.
- Filter locked/unlocked.
- Share achievement.
- View streak history.

States:

- First use.
- No achievements yet.
- Badge unlock celebration.
- Local persistence unavailable.
- Missing badge art.

Adaptive notes:

- Phone: streak summary followed by badge grid.
- Tablet/web: progress summary and badges side by side.

Asset usage:

- Badge art and trophy-shelf background. Badge names, dates, progress, and descriptions are Flutter-rendered.

## 9. Settings

Primary job:

- Give users control over weather units, personality, privacy, notifications, accessibility, and app information.

Core content:

- Units: temperature, wind, pressure, distance.
- Persona intensity.
- Theme mode.
- Reduced motion preference or system setting acknowledgement.
- Notifications.
- Location and privacy controls.
- Cache/data controls.
- About, legal, and app version entry points.

Interactions:

- Toggle settings.
- Select units.
- Adjust sliders.
- Open permissions.
- Clear cache.
- View about/legal details.

States:

- Settings loading.
- Save success.
- Save failure.
- Notification permission denied.
- Location permission denied.
- Offline.

Adaptive notes:

- Phone: grouped settings list.
- Tablet/web: grouped list with optional detail pane.

Asset usage:

- Optional decorative settings illustration only. All labels and controls are Flutter-rendered.

## Primary Navigation Proposal

Phone bottom navigation:

- Today.
- Forecast.
- Roasts.
- Radar.
- More.

The More destination can expose Meme Maker, Persona Closet, Progression, Settings, and About/legal routes.

Tablet/web navigation:

- Use navigation rail or adaptive side navigation with the same destinations.

## Production Readiness Checklist

Before a screen is considered ready:

- It compiles with no final generated assets.
- It handles loading, empty, stale/offline, error, and permission states.
- It uses shared tokens and shared components.
- It has screen-reader labels for icon-only controls and weather values.
- It respects reduced motion.
- It works at phone, tablet, and web widths.
- It keeps dynamic data out of images.
- It has at least a smoke/widget test where practical.
