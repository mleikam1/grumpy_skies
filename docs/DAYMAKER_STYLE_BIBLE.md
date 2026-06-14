# DayMaker Style Bible v1

## Product Position

DayMaker is a playful, premium, personality-driven weather app. It should feel polished enough to trust every morning and expressive enough to make checking the weather feel like a tiny ritual.

The app is not a joke wrapper around weather data. Accurate forecast information remains clear, scannable, and accessible. Personality appears through tone, motion, art, personas, rewards, and optional roast moments.

## Design Principles

- Weather first: current conditions, risks, timing, and decisions are always legible before personality layers.
- Personality with control: users can adjust intensity, tone, units, and notifications without hunting.
- Premium, not chaotic: use color, illustration, and copy with restraint. Dense screens should still feel calm.
- Adaptive by default: one responsive Flutter UI must support phone, tablet, and web breakpoints.
- Art supports UI: images create atmosphere and identity, while Flutter renders all real interface elements.
- Production before spectacle: every feature must tolerate loading, empty, stale, offline, permission-denied, and missing-asset states.

## Voice And Tone

DayMaker sounds like a witty weather companion that wants the user's day to go better.

Use:

- Short, confident forecast summaries.
- Playful roast lines that remain opt-in or adjustable.
- Friendly direct language for settings, errors, permissions, and safety weather.
- Context-aware personality: a storm warning should not be treated like a punchline.

Avoid:

- Mean-spirited insults, body shaming, protected-class jokes, or personal attacks.
- Copy that obscures real weather risk.
- Over-explaining jokes.
- Hard-coded locations, times, timestamps, forecast values, or settings labels inside artwork.

## Visual Identity

DayMaker should feel bright, tactile, and editorial, with enough contrast to read outdoors. The visual system can be colorful without becoming a one-note palette.

Suggested token families:

- Sky: clear daytime blues for primary navigation and confidence.
- Sun: warm yellow and amber accents for wins, streaks, and positive conditions.
- Storm: charcoal, violet-gray, and electric blue accents for severe weather and radar.
- Rain: teal and cool green accents for precipitation, humidity, and freshness.
- Heat: coral and red-orange accents for heat risk and alerts.
- Frost: pale cyan and cool lavender accents for cold conditions.
- Neutral: near-white surfaces, soft ink text, and elevated dark surfaces for dark mode.

Do not rely on a single hue family across the whole app. Weather state, persona state, and alert state should create controlled variation.

## Typography

Use Flutter-rendered text for all labels, forecast values, card headings, roast copy, timestamps, locations, settings labels, and accessibility strings.

Recommended roles:

- Display: app name, major temperature, screen hero moments.
- Title: section names, card headers, dialog titles.
- Body: explanations, forecast summaries, settings descriptions.
- Label: chips, controls, navigation, badges, secondary metadata.
- Numeral: temperature, precipitation chance, wind, UV, pressure, and hour labels.

Keep display text reserved for true focal moments. Compact panels, chips, cards, and settings rows should use tighter type sizes that fit without clipping on small phones.

## Layout And Density

Phone:

- Bottom navigation for primary app sections.
- Current condition summary above scrollable forecast modules.
- Horizontal modules for hourly data, persona cards, and badges only when they remain accessible.

Tablet:

- Two-column or master-detail layouts where useful.
- Preserve the same information hierarchy as phone.
- Avoid stretching cards until content feels sparse.

Web:

- Use responsive max widths for reading-heavy panels.
- Support pointer hover states and keyboard navigation.
- Do not create a separate web-only product experience.

## Motion

Motion should feel weather-like: drifting, revealing, brightening, settling, and pulsing. Use it to clarify state changes, not to distract from forecast reading.

Appropriate motion:

- Gentle background parallax or atmospheric loops.
- Persona reveal transitions.
- Radar overlay fade and scrub feedback.
- Badge unlock celebration.
- Pull-to-refresh and loading shimmer.

Respect reduced-motion settings. Provide still fallbacks for every animated asset.

## Artwork Rules

Generated artwork may be used for:

- Backgrounds.
- Mascots.
- Personas.
- Badges.
- Feature illustrations.
- Meme backgrounds.
- Radar overlays.
- Decorative art.

Generated artwork must not contain:

- Forecast data.
- Roast text.
- Timestamps.
- Locations.
- Settings labels.
- Navigation labels.
- Buttons, chips, toggles, forms, or other real UI.
- Any copy that must be localized, updated, or controlled by the app.

Every artwork prompt should reserve clean negative space where Flutter can overlay real UI when needed. Artwork should export at multiple aspect ratios when used as a screen background.

## Components

Build reusable Flutter components around design tokens:

- `DayMakerScaffold`
- `DayMakerNavBar`
- `WeatherHero`
- `ForecastCard`
- `MetricChip`
- `PersonaCard`
- `RoastBubble`
- `RadarControlBar`
- `MemeCanvasPreview`
- `SettingsSection`
- `AchievementBadge`
- `FallbackAsset`

Components should own layout and states, not screen files. Screens compose components and connect data.

## Accessibility

Minimum requirements:

- Dynamic type support where layout allows.
- Screen-reader labels for weather values and icon-only controls.
- High contrast for text over art.
- Non-color-only status indicators.
- Hit targets suitable for mobile.
- Keyboard traversal on web and tablet.
- Reduced-motion support.

Severe weather and safety-related information must be readable without relying on jokes, colors, or images.

## Asset Fallbacks

The app must compile before final generated image assets exist.

Use a centralized asset resolver with fallback placeholders for:

- Missing backgrounds.
- Missing persona portraits.
- Missing badge art.
- Missing meme templates.
- Missing radar overlays.

Fallbacks may be Flutter-rendered gradients, simple geometric placeholders, or bundled neutral images. They should look intentional enough for development builds and should not crash release builds.
