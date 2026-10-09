# Live app verification

Ran the production `lib/main.dart` entrypoint with the existing public weather
backend at `http://127.0.0.1:8766`, using a fresh localhost browser instance.
Manually searched the public city Overland Park, Kansas; no device location
permission or personal coordinates were used. This browser instance has separate
local storage from the iPhone installation. Real forecast data displayed 84°F,
42% humidity and 1013hPa at the time of inspection; these are historical capture
values, not a promised current forecast. Final refreshed Today/Roasts captures later showed 83°F and 44% humidity; the overview combines captures taken during the same review session, not a synchronized data snapshot.

Verified the actual app at a 390×844 logical viewport:

- Today loaded from the production backend with the original navigation shell.
- The seven-day sheet opened above the bottom navigation. Scrolling reached Thu;
  the long Tuesday thunderstorm condition and Wednesday/Thursday conditions were
  readable. The header/close control remained available.
- Details used clear labels, contrasting values and grouped sun/moon cards.
  Existing 7:22AM sunrise and 6:49PM sunset were shown. Missing AQI, UV, moon times
  and last-hour precipitation were unavailable rather than fabricated.
- The radar displayed the real OpenStreetMap city map without the CARTO watermark.
  The NOAA layer loaded through the real backend. Play changed to Pause and the
  frame label advanced from Latest to -6min; playback was then paused. Local dry
  imagery was not replaced with fabricated precipitation.
- Changed the app from Light to Dark through Settings. Weather and the displayed
  Karen quote/expression stayed identical. Dark Today, Details, daily sheet and
  radar were captured. The radar dark treatment leaves overlay colours intact.
- Roasts displayed the Complaining expression and badge with the actual local
  editorial quote. Share opened with exactly that quote. Make a meme opened the
  existing studio with the identical bottom caption. Returning used the existing
  editor → library → Fun flow. No social message or external share was sent.

After reloading the final artwork, selected all five personas in the live Roasts screen. Karen/Complaining, Frat Bro/Confident, Politician/Neutral, Grandpa/Complaining and 2-Year-Old/Neutral matched their actual selected quotes. Captured each, returned to Karen, and refreshed both Light and Dark Today/Roasts images. Appearance and selected city survived the browser reload.

`screenshots/live_*.jpg` are actual browser screenshots (including the debug ribbon).
Separate `after_*.png` and emotion galleries are explicitly controlled real-widget
fixture captures. Radar evidence also includes an isolated-screen current NOAA
viewport and separately labeled simulated error cases. Those evidence types are
not interchangeable.

The browser log also exposed the pre-existing optional splash mascot fallback
(`assets/mascots/daymaker_happy.png` absent); it is outside the refined screens.
The app's actual weather, radar and roast flows rendered and operated successfully.
