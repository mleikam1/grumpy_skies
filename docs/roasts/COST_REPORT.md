# Roast delivery cost measurements

Measured 2026-10-10 from this worktree with `dart tool/build_roast_release.dart` and `python3 tool/measure_roast_costs.py`. Counts, hashes and exact shard sizes are in `build/roast_release/release_report.json`.

Illustrations use decimal GB and gross USD at $0.15/GB before free allowances/tax, from [Firebase pricing](https://firebase.google.com/pricing). They are scenarios, not observed traffic or bills. Gzip sizes are actual locally encoded files; production CDN compression, deployed response headers and native/web transfer negotiation remain unverified because no update origin was authorized. HTTPS origin length changes the final manifest size.

| Scenario | Payload bytes / installation | 10k GB / USD | 100k GB / USD | 1m GB / USD |
|---|---:|---:|---:|---:|
| Cold web bundled roast JSON, raw (once) | 255,181 | 2.5518 / $0.38 | 25.5181 / $3.83 | 255.1810 / $38.28 |
| Cold web bundled roast JSON, measured local gzip (once) | 25,689 | 0.2569 / $0.04 | 2.5689 / $0.39 | 25.6890 / $3.85 |
| Warm web bundled JSON with retained persistent cache | 0 | 0.0000 / $0.00 | 0.0000 / $0.00 | 0.0000 / $0.00 |
| Optional updates, unchanged hashes (five manifests) | 7,170 | 0.0717 / $0.01 | 0.7170 / $0.11 | 7.1700 / $1.08 |
| Optional updates, one changed persona on all five checks, gzip | 36,655 | 0.3665 / $0.05 | 3.6655 / $0.55 | 36.6550 / $5.50 |
| Optional updates, one changed persona on all five checks, raw | 199,165 | 1.9916 / $0.30 | 19.9165 / $2.99 | 199.1650 / $29.87 |
| Optional updates, all five personas once plus five manifests, gzip | 35,008 | 0.3501 / $0.05 | 3.5008 / $0.53 | 35.0080 / $5.25 |
| Optional updates, conservative 30-day per-install budget incl failures | 1,048,576 | 10.4858 / $1.57 | 104.8576 / $15.73 | 1048.5760 / $157.29 |
| Existing five neutral portraits, if all fetched once | 6,272,199 | 62.7220 / $9.41 | 627.2199 / $94.08 | 6272.1990 / $940.83 |
| Existing fifty expression assets, if all fetched once | 62,955,894 | 629.5589 / $94.43 | 6295.5894 / $944.34 | 62955.8940 / $9443.38 |

Bundle: **530 active lines**, **255,181 raw / 25,689 gzip bytes**. Candidate manifest: **1,434 raw / 463 gzip bytes**. Largest persona: **38,399 raw / 5,897 gzip bytes**. The ~2 KB manifest / 200 KB gzip targets are satisfied by this candidate; that is not a measurement of a future 5,000-line catalog.

Payload rows exclude transport/TLS overhead. Runtime budget accounting adds 1,024 bytes per request and reserves worst-case bytes before attempting a download; failed/interrupted attempts retain their reservation. Thus the optional one-persona/five-check gzip case accounts for at least ten additional 1,024-byte overhead allowances. A 1 MiB device budget limits cooperative clients; it cannot prevent arbitrary public-URL downloads or cap global billing.

A native installation receives roast JSON and existing faces in its app package: zero incremental Hosting delivery in bundled-only mode. Initial web use must fetch uncached installed assets. The zero-byte warm row assumes the persistent web store is retained; eviction/private mode causes the cold path again. The roast selection itself does not fetch any asset pack. Image widgets may load an existing expression asset the first time that expression is displayed on web; that is static media transfer, not image generation. No artwork bytes were changed for this feature.

### Actual local production-browser transfer check

The final production web release ran at the separate origin `http://127.0.0.1:8927`. The local HTTP server served the roast bundle without compression: one cold request, 255,181 payload bytes. After a full page reload into the final build, the same bundle request count remained one: **zero warm roast-pack requests / zero warm roast-pack payload bytes** with retained browser storage. A real Chrome IndexedDB test separately verifies persistence through reconstructed cache instances.

One hundred visible Today “Another” actions were verified individually through fresh accessibility state, producing five distinct eligible clear-sky lines and no missing caption. Server deltas (including eleven preceding smoke actions) contained **zero API requests and zero roast-pack requests**; only the existing Karen excited and happy PNGs loaded once each. This local-server accounting does not claim visibility into external advertising traffic; the full widget interaction tests independently assert zero incremental categorized requests. Browser HTTP overhead, actual Firebase CDN compression and evicted/private storage remain outside this measurement. `work/roast-browser-verification.json` and before/after request snapshots contain the measurements; delivered evidence includes copies.

Existing fifty expression PNGs: 62,955,894 bytes across 50 files. Five neutral faces: 6,272,199 bytes. All source app assets: 91,003,975 bytes, not necessarily fetched together. Flutter JS/WASM/fonts, radar tiles, images, ads, geocoding and weather requests are additional costs outside the roast JSON table.

Classic Hosting bills CDN hits and misses as transfer. The pricing page states 360 MB/day free transfer while the [Hosting quota guide](https://firebase.google.com/docs/hosting/usage-quotas-pricing) states 10 GB/month; the model uses neither allowance. Confirm the project console before relying on either. Cache static immutable hashes long and the mutable manifest briefly using [Hosting cache controls](https://firebase.google.com/docs/hosting/manage-cache). A retained local cache avoids more traffic than a CDN hit.

The [Firebase pricing page](https://firebase.google.com/pricing) lists Remote Config request charges beyond 100,000 daily fetches, effective September 1, 2026. This implementation adds no Remote Config fetch loop. [Spend-cap documentation](https://firebase.google.com/docs/projects/billing/spend-caps) lists AI Logic, App Hosting, Functions and Extensions; classic Hosting is not included. Caps can overshoot during reporting delays. Budget alerts notify and do not stop services. No budget, quota or billing configuration was changed.

For weather, `functions/src/index.ts` handles one primary forecast refresh with current, hourly and daily One Call 4.0 endpoints. Additional pages, alert-detail requests, failed attempts and fallback endpoints can add calls. The [One Call 4.0 documentation](https://openweathermap.org/api/one-call-4) describes six endpoint families, per-page billing, 10-minute provider updates and a default 2,000-call daily setting. This feature does not alter that setting. The [OpenWeather pricing page](https://openweathermap.org/price) lists 1,000 daily calls free, then $0.0015/call; subscriptions and other APIs have separate terms.

Illustrative 30-day weather workload: four fresh app forecast refreshes per installation per day, no cache hits or failures, three upstream calls per refresh. Dollar column assumes every primary attempt is a billed One Call 4.0 call before allowances; it is not the owner's actual spend.

| Active installations | App forecast refreshes / 30d | Primary upstream calls / 30d | Gross One Call USD | Added roast weather calls |
|---:|---:|---:|---:|---:|
| 10,000 | 1,200,000 | 3,600,000 | $5,400.00 | 0 |
| 100,000 | 12,000,000 | 36,000,000 | $54,000.00 | 0 |
| 1,000,000 | 120,000,000 | 360,000,000 | $540,000.00 | 0 |

Actual backend cost also needs cache-hit ratio, endpoint mix, billed plan, deployment region, CPU/memory/duration, requests and account invoices. A read-only CLI check confirmed billing for the intended project is enabled. Budget listing failed because the Cloud Billing Budget API is disabled; existing budgets, spend caps, service quotas and actual spend therefore remain unverified. No API was enabled and no billing setting was changed. Recommended alert thresholds, once the owner sets a monetary budget, are 50%, 80%, 100% and forecasted 100%; inspect service quotas independently. Do not disable billing for the whole production project to contain humor traffic.
