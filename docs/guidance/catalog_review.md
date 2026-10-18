# Complete editorial and claim review

The supplied implementation pack was treated as editorial seed material. All 240 variants, all 40 family contracts, all 35 extra variant requirements, the global policy, and the predicate descriptions were reviewed. Source SHA-256 hashes are preserved in `variant_claim_review.json`. This was a model-assisted repository review, not an independent meteorological or medical certification. Runtime eligibility is proved separately by compiled predicates and tests.

The reviewed pack preserves every original family and template ID. It revises 171 messages and retains 69 with their evidence requirements. All 35 narrower guards survive explicitly. Each of the 240 audit rows names a practical action focus; wording-only duplication was revised, including the original morning/evening layering sequences. The validator also rejects exact normalized duplicate texts and within-family similarity of 0.90 or greater. These string checks supplement editorial judgment; they cannot prove semantic usefulness by themselves.

The longest final message is 134 characters and 21 words. There are no template placeholders, fixed numeric claims, route names, private activity names, provider credentials, or URLs in message text. Layout still needs responsive checks because a character budget does not guarantee one or two lines at every accessibility scale.

## Claim decisions applied across the whole catalog

| Claim area | Review decision |
| --- | --- |
| Current rain | Requires a fresh observation in the displayed area. A later forecast is never evidence that rain is falling now. |
| Likely/possible rain | Retain normalized, provider-supported liquid-rain probability bands. Probability does not establish amount, intensity, or rain for an entire event. |
| Lower-rain windows | Compare supported hourly probabilities over complete comparable intervals. Text names lower hourly chances, never a guaranteed dry, safe, or universally better period. |
| Rain ending trend | Describe lower later chances alongside current observed rain. Do not infer a verified end time or that rain has stopped. |
| Dog, walking, cycling preferences | Unguarded preference-only variants are conditional. Definite scheduled language retains known/user-selected activity-window guards. |
| Warm or hot families | Text uses warmth where the family can qualify on a warm threshold. It does not invent a hotter category, safe duration, pavement temperature, or verified cooler hour. |
| Fog or low visibility | Describe visibility concerns when the contract can be satisfied without explicit fog. Fog-specific action is conditional on encountering fog. |
| Commutes | Require the configured/known commute occurrence and matching area/time. Advice can allow flexibility; it does not claim measured congestion, a travel-delay number, road closures, an accident, or route-wide weather. |
| Ice, snow, wind | Freezing precipitation and snow require explicit evidence. Slippery surfaces remain conditional. Gust advice requires gust data, not sustained-wind inference. Umbrella advice retains its conflict exclusion. |
| UV and air quality | Use a matching named index/category and its actual period/location. A daily UV peak is not a current reading. Air quality does not imply pollen or smoke unless the source explicitly supports those separate facts. |
| After sunset | Use date/location-specific sunset evidence for the intended interval. Proposed activities remain conditional; the two definite planned variants retain the actual-window guard. |
| Events | Require established outdoor context, actual interval, resolved event location, and interval coverage. Current-area assumptions must be visibly disclosed by the UI. |
| Missing forecast | Only recoverable missing/stale data with an existing user-triggered refresh qualifies. Copy varies the practical decision to defer; it never creates an automatic retry or promises a refresh will work. |

Official alerts and known serious hazards override ordinary advice. Their absence or expiry never proves all-clear. Complete source availability, precision, freshness, temporal coverage, and location binding remain mandatory even if a catalog sentence sounds cautious.

## Narrower variant requirements retained

`fog_outing_03` requires walking context; `snow_outing_05` also requires walking context; `forecast_unavailable_02` requires current-forecast context.

The remaining 32 variants require `known_or_user_selected_activity_window`:

- `dog_rain_01`, `dog_rain_03`, `dog_rain_05`, `dog_rain_06`
- `dog_heat_01`, `dog_heat_03`, `dog_heat_04`
- `dog_cold_01`, `dog_cold_03`, `dog_cold_06`
- `dog_wind_01`, `dog_wind_02`, `dog_wind_03`, `dog_wind_06`
- `bike_rain_01`, `bike_rain_02`, `bike_rain_04`, `bike_rain_06`
- `bike_wind_01`, `bike_wind_02`, `bike_wind_03`, `bike_wind_04`
- `bike_heat_01`, `bike_heat_03`, `bike_heat_05`, `bike_heat_06`
- `bike_cold_01`, `bike_cold_03`, `bike_cold_05`, `bike_cold_06`
- `dog_after_dark_01`, `bike_after_dark_01`

Some revised messages are now more conditional than their original guard requires. Retaining the guard is deliberately conservative; an editorial rewrite never automatically removes an evidence prerequisite.

## Measured checked-in payload

| File | UTF-8 bytes | Gzip bytes |
| --- | ---: | ---: |
| `wingman_tips.en-US.json` | 56,512 | 9,000 |
| `wingman_tip_family_contracts.json` | 47,600 | 6,323 |
| Combined | 104,112 | 15,323 |

Gzip uses level 9 with a zero timestamp, measured independently for each exact checked-in JSON file. Review documentation is not part of the runtime catalog. `validation_report.json` is the machine-readable source for counts, bounds, sizes, and hashes; regenerate it after any content change.
