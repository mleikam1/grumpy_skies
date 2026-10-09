# Radar refinement — 2026-10-09

The reported “API KEY REQUIRED” map is fixed by replacing the unauthenticated CARTO basemap with the official OpenStreetMap raster service. The existing Flutter map, coordinate system, NOAA/OpenWeather overlays, frame API, pan/zoom, recentering, playback, and layer controls remain in place. No keys, billing, deployed configuration, or backend implementation changed.

## Diagnosis and provider policy

A read-only request to the exact former CARTO URL at `10/242/391.png` returned HTTP 200 and a 2,049-byte PNG containing the watermark, rather than cartography. The same coordinate from OSM returned HTTP 200 and a 46,378-byte valid Overland Park map. This explains why ordinary HTTP error handling did not report a basemap failure. See [response metadata](radar_evidence/tile_responses.json), [original tile](radar_evidence/carto_before.png), and [replacement tile](radar_evidence/osm_after.png).

CARTO's current [key documentation](https://carto.com/basemaps/apikey/) and [terms](https://www.carto.com/legal/basemap-terms/) require an issued basemap key; the terms permit watermarking unauthenticated requests and prohibit circumventing it. No watermark was removed or obscured. The app now requests a different, supported service.

The [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) allows interactive viewing with attribution, identifiable requests, caching, and no bulk/offline prefetch. The implementation uses exactly `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, a stable DayMaker-identifying native User-Agent, and `panBuffer: 0` to request the visible viewport. It retains Flutter's browser caching and flutter_map 8.3's default HTTP-aware native cache, including conditional revalidation and seven-day fallback freshness. No no-cache headers or referrer suppression were introduced. [flutter_map documents this caching behavior](https://docs.fleaflet.dev/layers/tile-layer/caching).

OSM's service is best effort and has no SLA. A higher-traffic launch may need an owner-selected commercial or self-hosted service. The URL is centralized in `radarBasemapUrl`, next to the identification constant. A future provider change must update attribution and comply with that provider's terms. This change does not enable bulk downloads or offline map packs.

## UI and truthful state

- Location, mode, and frame labels now have separate readable lines. Status badges use semantic text colors; the selected frame uses navy on yellow.
- Ordinary map actions use light/dark surface colors with contrasting icons. Yellow is reserved for playback emphasis. All seven actions remain available; controls retain at least 48 logical-pixel targets.
- Chaos score and timeline text no longer use low-contrast yellow/cyan labels on white surfaces.
- In dark appearance, flutter_map's cartographic dark filter is applied only to the basemap. Radar overlays and their source colors are unchanged.
- Visible, linked OSM attribution and actual radar source attribution sit above both the notice and expandable control sheet. They wrap with large text instead of clipping offscreen or disappearing beneath the sheet. The narrow `url_launcher: 6.3.2` dependency supplies the native/web licence link; no existing dependency versions were upgraded.
- Visible basemap tile errors are tracked independently from radar health. A map failure never produces a claim that the base map is usable. The warning clears when failed tiles recover or leave the rendered map.
- OpenWeather authorization errors use plain user-facing wording. No fake precipitation tiles, replacement forecasts, or invented coverage are shown.

## Live checks and evidence

At 2026-10-09 22:31 UTC, the existing backend reported NOAA MRMS available with a valid PNG and 14 frames. The review captured the actual current frame `1791584099` through the existing `/radar/tile` API. The same read-only check reported upstream 401 / `openweather_key_rejected` for both `openweather_futurecast` and `openweather_global`. Those are separate server-key authorization problems; resolving them requires the owner's service access/configuration and was not attempted here. See [health responses](radar_evidence/backend_health.json) and [viewport tile response metadata](radar_evidence/noaa_viewport.json).

| Evidence | Light | Dark |
| --- | --- | --- |
| Real OSM basemap + actual current NOAA tiles | [Map](radar_evidence/light_radar_live_noaa.png) | [Map](radar_evidence/dark_radar_live_noaa.png) |
| Real OSM basemap + simulated radar unavailable state | [Map](radar_evidence/light_radar_map.png) | [Map](radar_evidence/dark_radar_map.png) |
| Expanded controls + unavailable state | [Controls](radar_evidence/light_radar_controls.png) | [Controls](radar_evidence/dark_radar_controls.png) |

Screenshots render the real `RadarScreen` at 390×930, with actual bundled fonts. They isolate the screen, so the outer app navigation is absent. Real map/NOAA bytes were fetched only for this single visible viewport and loaded by a test-only provider; there are no diagnostic tile assets in the application. The live-map captures hide the synthetic fixture Chaos Meter. The separate unavailable-state captures intentionally use the approved weather fixture for that meter and synthetic radar failure responses; they do not claim current weather or coverage. No precipitation was added to the live source imagery.

Visual review: city labels and map roads remain legible, the location and mode are no longer ellipsized at normal phone width, dark controls have bright foregrounds, light controls use navy ink, and attribution stays visible when controls expand. The sheet scrolls to the precipitation legend and extended details rather than squeezing them into the viewport.

## Validation

`flutter test --no-pub test/radar_refinement_test.dart test/radar_screen_test.dart`: **13 passed**. Tests cover endpoint/identity/prefetch configuration, separation and recovery of map/overlay errors, zoom and recenter behavior, playback progression, attribution placement above the sheet, both themes, and 320-wide text at 200%. Tests use memory tiles by default and make no live tile requests.

Capture invocation (explicit opt-in, given the diagnostic viewport directory):

```sh
flutter test --no-pub test/radar_refinement_test.dart \
  --dart-define=CAPTURE_RADAR_REFINEMENT=true \
  --dart-define=RADAR_REVIEW_TILE_DIRECTORY=/absolute/path/to/radar-viewport
```

The directory contains the single-view OSM `10_x_y.png` files, current NOAA `noaa_10_x_y.png` files, and raw `noaa_frames.json`/`noaa_health.json`. Missing expected tiles fail capture rather than producing substitute map imagery. These are temporary review inputs, not an offline feature or bundled map archive. Ordinary test runs need none of these files.
