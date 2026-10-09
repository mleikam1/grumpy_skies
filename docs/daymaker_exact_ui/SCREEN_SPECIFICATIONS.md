# Screen specifications

## Scope and reference status

**Approved raster targets:** Today, Roasts, Fun, each shown in Light and Dark.

**Derived screens:** Radar, forecast detail, location selection, Settings, About/legal, welcome, roast reveal, meme library/editor/export, all loading/error/permission states, and tablet/web arrangements. These must use the same components and theme system and preserve the app's existing capabilities. They are specified here but are not separately pictured or approved as exact layouts.

The light board controls geometry, static UI wording, and character identity. The dark board supplies the alternate palette. All dimensions below are inferred implementation starting points at 390 logical pixels wide. Calibrate with actual app captures. Never force both references to different widget geometry because their generated images vary slightly.

## A. Today — `/forecast`

### Composition, top to bottom

**Header.** Left: compact yellow sun symbol and `daymaker.` wordmark. Right: circular settings gear. Under this: location-pin icon, selected place text and down-chevron; status chip at right. The place row opens the existing location-selection flow. Do not use the operating-system status bar as an app header.

**Weather hero.** Condition eyebrow above a large left-aligned temperature. Feels-like and high/low below. At right, the expressive sun/cloud illustration, with soft weather atmosphere behind the hero. Keep the number, labels, and art from colliding; allow the art to sit within a bounded scene rather than in an unrelated full-width card. Suggested hero height about 200 at normal text scale; larger text may expand it. Use adaptive numeral sizing for negative/triple-digit values without scaling the whole page.

**Upcoming weather insight.** A short rounded horizontal card: small mint umbrella, bold “A little plot twist at 5 PM.”, supporting “Rain chance rises to 40%.”, right chevron. This copy is a fixture example only. Production content derives from the existing forecast data with explicit probability/period meaning; when no supported insight exists, omit it or show a truthful alternate within the same pattern. Tap opens appropriate forecast detail, not a placeholder snackbar.

**Featured persona card.** A pink card in Light / deep plum in Dark. Karen artwork at left occupies roughly 30% of the width. Right: “Karen's take” and ROAST QUEEN subtitle, FOR FUN chip, the current quote, then Another and Share controls. Keep the light reference's hierarchy in dark mode. Initial visual fixture uses Karen; production respects the user's saved persona and adapts the same component for the cast.

Do not stretch the portrait to fill the card. Use a shared PortraitStage with safe image padding, documented anchors, and a halo/surface independent of the image. Long quotes expand the text/card; never cut off text with a fixed-height screenshot mask. Tap Another changes locally selected copy without a new weather/AI request. Share opens an actual share action; include a Make a meme option that carries the exact displayed quote and captured weather context.

**Hourly forecast.** Heading with See all. Five small rounded tiles are visible at reference width. They form a horizontal scroll strip for available hours, with time, condition icon, temperature, and precipitation probability where supported. The initial tile has a subtle blue selected/current surface. Show current/next hours from provider timestamps in the selected location timezone; do not derive them from the local device zone blindly.

**7-day forecast.** Heading with See all and compact rows in one rounded container: weekday, weather icon, high, low. The screenshot displays only the first three rows before navigation, not a three-day product limit. The rest scrolls normally. If the current provider supports a different day count, make the heading truthful without fabricating missing days.

**Bottom navigation.** Today, Radar, Roasts, Fun in that order. Highlight Today in yellow. Keep the reference capsule/rounded selection style and provide scroll-bottom padding equal to actual navigation plus system inset.

### Fixture-visible values

72°F; Partly cloudy; feels like 74°F; H 76°F / L 61°F. Hour tiles: Now 72°, 11 AM 74°, 1 PM 76°, 3 PM 73°, 5 PM 69° with 40% at 5 PM. Initial Karen quote: “I'd like to speak to the manager of this humidity.” Full synthetic records live in the fixture JSON. They never replace production data.

### Below the pictured fold

Keep supported wind, humidity, precipitation, sunrise/sunset, additional metrics, source/time disclosure, and existing ad eligibility. They may use matching compact sections after the key reference content. Do not add a new large dashboard region above the hourly row or move advertising into the hero to fill the first viewport.

## B. Roasts — `/roasts`

### Composition

Header “Roasts”, settings gear. Small uppercase “YOUR FORECAST. THEIR OPINION.” in an accent treatment. Big two-line title: “Same weather. / Different takes.”

Five portrait selectors in a single horizontal row where space allows, ordered Karen, Frat Bro, Politician, Grandpa, 2-Year-Old. Use the new artwork; captions below; selected item has a thin cyan ring/highlight. On narrow screens the row scrolls horizontally rather than shrinking tap regions below accessibility targets.

Large featured card beneath. In the visual fixture Grandpa is selected. Small “MEET YOUR FORECASTER”; large “Grandpa.”; outlined WEATHER WISEGUY badge. Grandpa's image at the upper/right, quote in the remaining space, with no text through the face. Quote: “At my age, clouds just mean a good excuse for a nap.” Bottom line: small condition icon with “72° · Partly cloudy” and place text. Surface is pale warm pink in Light, deep blue in Dark; geometry is identical.

Two buttons below the card: yellow Another roast and a neutral Share. These buttons are outside the card as in the light reference. Follow with “More from the crew” / View all and compact preview rows, such as Karen: “Sunshine? Cute. Let's see it last.” Do not manufacture relative timestamps or public popularity; show time only when a real local history event exists.

Bottom nav highlights Roasts. Grandpa is the **fixture selection**, not a rule to overwrite the user's default. Tests explicitly select Grandpa; production shows the saved selection. Switching selection uses the same panel geometry for all five personas.

### Behavior

Connect active weather to the same canonical displayed/cached snapshot as Today. Preserve honest sample indicators in previews and errors. Use the local roast-pack selector and repetition avoidance. Save selection with the existing controller. Keep favorite/history functionality if present; add history records only for actual events, not each rebuild. Keep the exact currently displayed text immutable when handing it to sharing/editor flows.

Long copy, empty history, missing weather, missing portrait, and failed persistence must have designed states. Hide or label unsupported actions rather than presenting a success message for work that never occurred.

## C. Fun — `/fun`

### Composition

Header “Fun Zone”, gear. Eyebrow “WEATHER + MEMES = BETTER DAYS”. Large two-line title: “Turn your forecast / into a punchline.”

A compact three-part pill selector: **Make a meme · Templates · My memes**. Each has a genuine purpose. Make a meme is selected in the reference. Keep top-level primary navigation separate from these local tabs.

Featured Meme Studio card. Small MEME STUDIO badge; title “Same skies. / New material.” Supporting copy: “Use today's weather, add a little attitude, and make it a meme.” Action: “Create a meme” with arrow. To the right: sunglasses cloud and playful text sticker GOOD WEATHER BAD DECISIONS. The Light card is warm yellow; Dark uses the pictured deep blue treatment and bright yellow action. This is a theme-specific semantic surface/action variant, not different content or widget structure.

Quick templates heading with See all. Three compact preview tiles: Current mood, Monday energy, This weather…. Artwork and brief caption teasers occupy the same proportions in both themes. Show three at the reference width; retain readable text and tap targets in narrower/large-text layouts. The tiles open real editable documents, not a flat image of the whole tile.

Featured meme heading and beach/sun meme preview. The scene contains a sunglasses sun and “FORECAST: 100% CHANCE OF NO CHILL.” The preview is legitimate meme content, but its source document should contain text layers so the generator can customize it. Users can open/use the template, not merely view a screenshot.

Bottom nav highlights Fun. Local tab selection does not unexpectedly switch the primary nav state.

### Existing fun experiences

Do not delete Fortune Cookie, Crazy Day Predictor, Weather Menace, progression, or other functioning Fun capabilities to match a first-screen crop. Place them below the featured meme or in a consistent secondary collection. These are for-fun activities and must not masquerade as provider forecasts. Persist only actual earned progress; make repeat rewards idempotent. Give each action a working result and preserve navigation back to the hub.

## D. Secondary screens — same tokens, real functionality

| Surface | Required layout and behavior |
|---|---|
| Radar `/radar` | Map-first composition, compact header/gear and location, real layer/mode controls, readable legend/source/time, accessible timeline and play/pause. Keep frame continuity and previous valid tiles during replacement. Distinguish observations from forecast. Show only supported/available horizons. Surface unavailable/partial coverage instead of fabricated maps. No joke/ad overlays competing with warnings or controls. |
| Forecast detail | Matching header/back action, useful hourly/daily expansion and metric cards. Real units/timezones, source/age, and textual equivalents for any chart. Only supported data; no invented radar precision or exact rain start time. |
| Location selector | Shared sheet/page with search, current location, saved locations where supported, loading/error results, and permission-denied recovery. Never force permission to use manually selected locations. Handle identical city names with region/country. |
| Settings `/settings` | Clear grouped sections: Appearance (Light/Dark/System), location, units, default persona, motion, notifications, advertising/privacy, data sources, About, feedback. Theme preview changes actual UI and persists. Do not ship fake feature status or dead chevrons. |
| About/legal | Same typography/cards, real build version and credits, functioning policy/license navigation. Do not claim that a generic development privacy paragraph is a legally reviewed production policy. Keep missing owner-supplied policy/contact configuration explicit. |
| Welcome/splash | Use the approved sun/wordmark style in both themes. Do not force returning users through a welcome CTA on every launch. Never delay weather artificially for an animation. Maintain first-run location choice. |
| Roast reveal | Use the same selected cast asset and actual local roast context. Accessible tap/button alternative to gestures; reduced-motion version; no hardcoded fake XP/streak/unlocks. Reuse shared card and sharing behavior. |
| Meme library | Actual templates, favorites, and saved local documents; filters/search only when working. Preserve existing document IDs/formats and local media. Thumbnail previews use the new design style without corrupting saved user projects. |
| Meme editor | Canvas first, contextual Text/Art/Stickers/Weather/Layers controls, undo/redo, save status, Preview/Export. Hide regular bottom app nav while editing, preserve warning access and ad/modal guards. On desktop use canvas plus inspector; on mobile use trays/sheets without keyboard covering selected input. |
| Export preview | Preview actual generated image, choose supported aspect/size, share/save via existing platform services, correct success/cancel/failure state, back to editing without losing work. Keep safety and monetization state until operations actually complete. |

Secondary screens must work in both modes. Their first layout is a derived extension, not a copy of an unrelated earlier board. Do not add a new mandatory account, new cloud AI dependency, weather-provider migration, or premium paywall as part of this UI project.

## E. Common state designs

Loading: retain page structure with quiet placeholders/skeletons; keep decorative motion minimal. Error: informative text, retry/change-location controls, and no fictional weather. Offline with cache: keep last real values with Cached/Stale/source-time labels. Empty: useful next action, not a screen full of disabled cards. Missing image: a bounded development fallback, with production asset status reported. Partial provider data: omit only unavailable metrics, not a whole functioning forecast.

Severe alerts: plain-language source, location, validity and full detail access. Suppress humorous framing and monetization where existing safety gates require it. Do not transform alerts with persona voices. Never style stale/unavailable safety data as “all clear.” Preserve current editor work while exposing the warning.

## F. Responsive and platform rules

At 390 logical pixels, match the approved composition closely. Test 320, 360, 390, and 430 widths, and short-height/landscape devices. At 600–1023 use a considered tablet layout; at 1024+ use a bounded multi-column dashboard and navigation rail. Do not stretch portraits or turn text into viewport-scaled art. Reuse widgets/data/state on every target.

Respect iOS safe areas, Android navigation/keyboard insets, system text scaling, web browser back/deep links, and pointer/keyboard focus. OS chrome is platform-rendered. Save drafts and retain state through rotation/theme changes. Keep the same component order between themes at the same width and text scale.
