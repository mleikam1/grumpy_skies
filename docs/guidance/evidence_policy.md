# Evidence and local selection policy

The immutable adapter reads the WeatherBundle already displayed by Today or the
validated event-weather cache entry returned by PlanCast. It cannot call a
repository. The current provider is OpenWeather; hourly/daily forecast attribution
preserves the existing backend's forecastSource (including National Weather
Service fallback). Unknown provider metadata is labeled unknown, not invented.

Each EvidenceField carries canonical value/unit, availability, observation versus
forecast kind, source timestamp, optional issue timestamp, retrieval timestamp,
covered interval, location identity, precision and timestamp meaning. Retrieval
never resets source age. Missing values and unsupported capabilities stay absent.
Current observations require the original `sourceUpdatedAt`; neither `lastUpdated`
nor `fetchedAt` can substitute for it. Legacy cached payloads without explicit
field-availability metadata remain usable by the existing weather display, but
cannot support new guidance until the app's normal refresh provides verified
evidence. Guidance never requests that refresh itself.
Probabilities are fractions internally, converted from the DTO's explicit percent
contract. Celsius and km/h are canonical; presentation respects temperature units.
Named AQI schemes are required for index thresholds. Current UV can only come from
the actual current record, never a daily maximum.

The existing DTO does not retain a separate AQI observation timestamp or coverage,
so the production adapter suppresses AQI claims. Typed rule tests cover named
OpenWeather and US EPA indices for a future correctly attributed snapshot; this
does not enable a new AQI request. Forecast issue time is also unavailable. The
adapter explicitly identifies its conservative bundle-observation age anchor and
leaves issueTime absent; it does not claim this is a provider issuance timestamp.
Unknown hourly gusts, visibility and intensity are not filled using current values.
NWS synthetic OpenWeather-compatible codes do not prove measured rain intensity;
retained condition text disambiguates freezing rain/sleet and mixed precipitation.

## Conservative defaults

GuidancePolicy contains named configurable product thresholds. Current weather and
current UV expire after 30 minutes; forecast evidence after 6 hours from its
original source anchor; typed AQI after 1 hour; checked alerts after 10 minutes.
Location validity and the supporting forecast/action interval can expire sooner.
These policies never extend the app's existing weather/alert cache lifetimes.
PlanCast additionally requires its normal usable assessment, matching cached venue,
unexpired location basis, and actual interval coverage. Timed events with only a
daily outlook keep their existing factual outlook and omit hourly event guidance.
All-day dates use event-location IANA civil bounds, including 23/25-hour DST days.

Rain copy uses possible at 0.30–below 0.60 and likely at 0.60 or above, with liquid
rain type independently required. Weather type, chance and intensity remain
separate. Fresh current rain takes precedence over a conflicting low forecast.
Last-hour accumulation alone cannot prove rain is falling now.

Warm 27°C, hot 32°C, cold 7°C, cool 16°C, a 6°C material phase change,
32 km/h notable gusts/umbrella conflict, 1,000 m low visibility, 70% humidity
or 18°C dew point, and UV Index 3 are configurable product heuristics, not
medical, dog-safety, road-safety or universal comfort standards. Serious
temperature/wind/condition and official-alert gates run before ordinary ranking.
The existing original official-alert panel and instructions remain intact.

Comparisons cover every intersecting hour for the selected 15–180-minute duration
within a 12-hour horizon. Missing hours are unknown. Known hazardous windows are
rejected before scoring; supported temperature, wind/gust, daylight and air-quality
dimensions affect suitability. A meaningful rain improvement is at least 0.20.
Copy remains about lower rain chances and displays the comparison interval; an
internal worst-hour score is never displayed as an outing-wide probability.

## Preferences, time and persistence

Defaults are general outing advice. Optional dog walking, cycling, walking/running
and driving preferences remain device-local. Driving includes explicit weekdays
(initially Monday–Friday), an overnight-capable local commute window and outing
duration. The area is the forecast location being viewed, not an inferred home,
work address, route, actual commute or travel plan. Conditional labels distinguish
interests/routines from confirmed activities. Calendar titles are never analyzed by
the guidance layer.

Selections pin independently of the visible-history ring. Material evidence,
location, context, preference, alert or expiry changes invalidate selection.
Only freshly measured visible exposure records an impression, once per situation.
The ring keeps at most 100 records and 14 days, stores opaque scope/location hashes
without calendar titles or addresses, and batches local writes. Overlapping
intervals at the same point deduplicate ordinary actions across slots; separate
later events remain independent. Continuing serious hazards bypass cooldowns.
No account/sign-in system or settings sync exists in this checkout. resetHistory
is the explicit boundary a future account switch must invoke; history must never
join account settings sync.

Local boundaries and app resume reevaluate visible slots, including currently
empty optional slots. There is no background polling, new notification content,
push infrastructure, content updater, analytics upload or network dependency.
Bundled web assets remain normal application delivery, not a remote tip service.
Local cache or catalog failure cannot trigger a guidance repair request.
