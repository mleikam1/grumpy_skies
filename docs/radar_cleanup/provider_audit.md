# Radar provider and timing audit

Inspected 2026-10-18 for the approved Radar UI cleanup. This is an audit of the existing application and provider interfaces, not a request to change subscriptions or backend infrastructure.

## Existing data path

`OpenWeatherBackendClient` owns the existing `/radar/noaaFrames`, `/radar/futureFrames`, `/radarFrames`, `/radarHealth`, and `/radar/tile` interfaces. The UI changes keep those interfaces and the existing shared Provider architecture. Exact simultaneous client requests are coalesced by URL. Radar metadata responses have a 60-second HTTP cache lifetime; successful proxied tiles use 120 seconds plus 120 seconds stale-while-revalidate. Failed tile fallbacks have a separate short cache policy. These headers are not proof that a frame was observed recently.

The baseline screen checks frame metadata every minute, plays at 900 ms per frame, checks selected-frame health with a 260 ms debounce, and probes at most two upcoming frames. The cleanup retains the refresh interval and playback cadence while stopping unnecessary hidden/background work. Expanding, opening a panel, and opacity changes do not initiate an application-level refresh. The separate controller and map tests verify these behavior boundaries.

OpenStreetMap remains the raster basemap. The map uses its existing HTTP-aware cache and visible-viewport tile requests with `panBuffer: 0`. Roads and place labels are already baked into each basemap raster tile; there is no independent vector label layer to reorder. Changing weather opacity preserves the weather provider's colors. Native radar zoom remains 3–12 for NOAA and 3–7 for OpenWeather, overzoomed within the app's existing 3–12 map range.

## Observed radar

The existing U.S. source identifier is `noaa_mrms`. Its actual upstream is the NOAA `radar_base_reflectivity_time` ImageServer. The backend reads its `idp_validtime` records, clusters nearby duplicate instants, retains the existing recent-history window, and validates candidate frames against a location tile. It returns only renderable frames, including irregular intervals or gaps. Frontend labels and timeline positions use those actual returned timestamps rather than generating a 90-minute timeline.

The [active NOAA ImageServer metadata](https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer?f=pjson) identifies an MRMS base-reflectivity composite, four-band processed imagery, and no color map. Its nominal service update and coverage description does not guarantee a frame on every interval. The [same product's legend endpoint](https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer/legend?f=pjson) supplies RGB band swatches, not a reflectivity color-to-value scale.

Reflectivity is measured in dBZ and is not a direct rainfall-rate measurement. [NWS's radar product explanation](https://www.weather.gov/radarfaq/) identifies the distinction. A mockup's Light/Heavy gradient, the older screen's Severe color label, or a different product's palette is insufficient evidence for a numeric legend. Keep source imagery unmodified and show an honest reflectivity/provider-scale explanation with a source link where the active interface does not supply a verified palette.

## FutureCast and global coverage

FutureCast continues using `/maps/2.0/radar/us/forecast/{z}/{x}/{y}?tm=...`, not OpenWeather's unrelated PA0 layer. The [official documentation for this exact product](https://openweathermap.org/api/us-precipitation-map-forecast) describes U.S. coverage, 10-minute times, five hours of forecast availability, and native zoom 3–7. It provides neither a numeric color scale nor a model issue timestamp. The existing backend requests up to six hours and probes candidates; the UI uses returned renderable frames and does not promise that every requested hour is available. Missing access or missing frames remains unavailable, not confirmed dry weather. No paid plan or new provider is added.

The non-U.S. Live mode preserves the existing `openweather_global` path `/maps/2.0/radar/forecast`. Its metadata route currently constructs a two-hour recent candidate range rather than querying observed-frame records. Tile health still determines availability. This limitation is inherited from the existing provider adapter; the UI must not imply NOAA coverage worldwide. The forecast mode remains subject to the existing provider availability checks. Credits must name OpenWeather for either OpenWeather source.

Unlike the U.S. product, the [exact global radar product documentation](https://openweathermap.org/api/global-precipitation-map-forecast) supplies a complete discrete dBZ color table. The cleanup's `RadarColorScale` may therefore display those documented bins for `openweather_global`. This is a reflectivity scale, not mm/h. The global product's palette must not be applied to the distinct `/radar/us/forecast` product without an explicit provider equivalence statement. None was found in the U.S. product documentation. All scale data is bundled; no runtime legend request is added.

## Three separate times

1. `RadarFrame.timestamp` is the imagery's valid instant. It is never replaced by the phone clock. Newest available observation is labeled Latest; older selections are labeled Observed; FutureCast always says Forecast precipitation.
2. `refreshedAt` is local completion time of the last successful metadata response. It is labeled Metadata refreshed, not observed/issued/updated weather time. Downloading an old frame does not reduce its observation age.
3. Forecast issue time is absent from the existing backend response and `RadarFrameSet`. The Details label explicitly says it was not provided. No synthetic issue time and no metadata-only network request are added.

`RadarPresentation` uses the application's IANA timezone helper with the selected location's existing weather timezone. It includes dates when crossing local midnight, and UTC offsets distinguish repeated DST times. When an IANA zone is absent for a forecast, the display explicitly falls back to UTC rather than extending a current fixed offset through a possible DST transition. Observation-only fixed offsets remain supported. Full Details preserve provider seconds; the compact dock displays hours/minutes.

The timeline uses elapsed UTC time, snaps to real renderable frames, and labels actual first, midpoint-nearest, and last frames. It does not fill metadata gaps with generated imagery or evenly spaced weather times.

## Chaos and alerts

The existing `ChaosScoreService` combines the selected location's current conditions, next 12 hourly records, first 60 minute-precipitation records, wind/gusts, and supplied alerts. It starts at 12 and applies existing minimum scores for precipitation, wind, and thunder/alert signals. This UI task does not change the algorithm. Its categories remain Calm (0–20), Mild (21–40), Messy (41–65), Chaotic (66–85), and Certified chaos (86–100).

This is an application-owned weather signal score, not a measurement of the selected radar pixel or an official warning. It is appropriate only on the latest observed frame, with usable current weather. Historical and forecast frames do not receive a manufactured time-specific Chaos score. The existing `weatherFreshness` policy classifies observations older than 30 minutes as stale and rejects future/invalid source times. Offline-cache state must not masquerade as fresh current signals. No new weather read or polling loop is needed to decide visibility.

The repository's ordinary current-weather cache is 10 minutes and may return an explicitly marked offline fallback after failures. Retrieval cache lifetime does not reset `current.sourceUpdatedAt`. The baseline Radar screen loaded this weather on entry and location change; it did not have a separate Chaos refresh timer. Official active alert access remains independent of optional Chaos display.

## Verification boundary

The audit inspected the repository and public provider descriptions. No production backend deployment, cloud configuration, provider plan, database, analytics, or app-store action was performed. A successful preview with a deterministic tile fixture proves control layout, not live provider coverage. Live tile failures and unsupported FutureCast access must be reported separately from successful local control/state tests.


### HTTP 200 transparent fallback tiles

The existing backend can return a **256 × 256 transparent PNG with HTTP 200**
when an upstream tile fails, marked by `X-Grumpy-Skies-Tile-Fallback`. The current
`flutter_map` image provider does not expose this response header to its
`TileImage` listeners. Decoding that image successfully therefore proves that
an image loaded; it does not independently prove weather coverage or clear skies.
A dimension check cannot distinguish this fallback from an ordinary 256 × 256
tile and is deliberately not used.

The cleanup preserves metadata renderability checks and the selected-location,
selected-frame health probe. Known health failures remain visible even when
transparent imagery decodes successfully. The latest probe Future is reused
when returning from a hidden state or a brief mode switch, so invalidating stale
UI delivery does not erase its unavailable result or issue another identical
request. Actual image/network errors are also surfaced separately.

A failed HTTP-200 tile in a panned area can still escape that selected-location
probe. This inherited per-tile header limitation remains unverified by the
current renderer, and absence of color is not presented as confirmed dry
weather. Solving it completely requires extending the existing tile-provider
response handling while preserving cache behavior; no additional viewport
polling, backend changes, or replacement provider was introduced for this UI
refinement.
