#!/usr/bin/env python3
"""Measure release/artwork bytes; model delivery without inventing live billing."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
release = json.loads((root / 'build/roast_release/release_report.json').read_text())
personas = [p['persona'] for p in release['packs']]
art = [p for persona in personas for p in (root / 'assets/personas' / persona).glob('*.png')]
neutral_bytes = sum((root / 'assets/personas' / persona / 'neutral.png').stat().st_size for persona in personas)
art_bytes = sum(p.stat().st_size for p in art)
all_assets = sum(p.stat().st_size for p in (root / 'assets').rglob('*') if p.is_file())
max_persona = max(p['gzip_bytes'] for p in release['packs'])
max_persona_raw = max(p['bytes'] for p in release['packs'])
all_personas = sum(p['gzip_bytes'] for p in release['packs'])
manifest = release['manifest_bytes']
# At least seven elapsed days, including a cold check at day zero: <=5 in 30d.
scenarios = {
    'Cold web bundled roast JSON, raw (once)': release['bundled_bytes'],
    'Cold web bundled roast JSON, measured local gzip (once)': release['bundled_gzip_bytes'],
    'Warm web bundled JSON with retained persistent cache': 0,
    'Optional updates, unchanged hashes (five manifests)': 5 * manifest,
    'Optional updates, one changed persona on all five checks, gzip': 5 * (manifest + max_persona),
    'Optional updates, one changed persona on all five checks, raw': 5 * (manifest + max_persona_raw),
    'Optional updates, all five personas once plus five manifests, gzip': 5 * manifest + all_personas,
    'Optional updates, conservative 30-day per-install budget incl failures': 1024 * 1024,
    'Existing five neutral portraits, if all fetched once': neutral_bytes,
    'Existing fifty expression assets, if all fetched once': art_bytes,
}
lines = ['# Roast delivery cost measurements', '',
    'Measured 2026-10-10 from this worktree with `dart tool/build_roast_release.dart` and `python3 tool/measure_roast_costs.py`. Counts, hashes and exact shard sizes are in `build/roast_release/release_report.json`.', '',
    'Illustrations use decimal GB and gross USD at $0.15/GB before free allowances/tax, from [Firebase pricing](https://firebase.google.com/pricing). They are scenarios, not observed traffic or bills. Gzip sizes are actual locally encoded files; production CDN compression, deployed response headers and native/web transfer negotiation remain unverified because no update origin was authorized. HTTPS origin length changes the final manifest size.', '',
    '| Scenario | Payload bytes / installation | 10k GB / USD | 100k GB / USD | 1m GB / USD |',
    '|---|---:|---:|---:|---:|']
for scenario, byte_count in scenarios.items():
    columns = [f'{byte_count*n/1e9:.4f} / ${byte_count*n/1e9*.15:.2f}' for n in [10000,100000,1000000]]
    lines.append(f'| {scenario} | {byte_count:,} | '+ ' | '.join(columns)+' |')
lines += ['', f"Bundle: **{release['total_roasts']} active lines**, **{release['bundled_bytes']:,} raw / {release['bundled_gzip_bytes']:,} gzip bytes**. Candidate manifest: **{manifest:,} raw / {release['manifest_gzip_bytes']:,} gzip bytes**. Largest persona: **{max_persona_raw:,} raw / {max_persona:,} gzip bytes**. The ~2 KB manifest / 200 KB gzip targets are satisfied by this candidate; that is not a measurement of a future 5,000-line catalog.", '',
    'Payload rows exclude transport/TLS overhead. Runtime budget accounting adds 1,024 bytes per request and reserves worst-case bytes before attempting a download; failed/interrupted attempts retain their reservation. Thus the optional one-persona/five-check gzip case accounts for at least ten additional 1,024-byte overhead allowances. A 1 MiB device budget limits cooperative clients; it cannot prevent arbitrary public-URL downloads or cap global billing.', '',
    'A native installation receives roast JSON and existing faces in its app package: zero incremental Hosting delivery in bundled-only mode. Initial web use must fetch uncached installed assets. The zero-byte warm row assumes the persistent web store is retained; eviction/private mode causes the cold path again. The roast selection itself does not fetch any asset pack. Image widgets may load an existing expression asset the first time that expression is displayed on web; that is static media transfer, not image generation. No artwork bytes were changed for this feature.', '',
    f'Existing fifty expression PNGs: {art_bytes:,} bytes across {len(art)} files. Five neutral faces: {neutral_bytes:,} bytes. All source app assets: {all_assets:,} bytes, not necessarily fetched together. Flutter JS/WASM/fonts, radar tiles, images, ads, geocoding and weather requests are additional costs outside the roast JSON table.', '',
    'Classic Hosting bills CDN hits and misses as transfer. The pricing page states 360 MB/day free transfer while the [Hosting quota guide](https://firebase.google.com/docs/hosting/usage-quotas-pricing) states 10 GB/month; the model uses neither allowance. Confirm the project console before relying on either. Cache static immutable hashes long and the mutable manifest briefly using [Hosting cache controls](https://firebase.google.com/docs/hosting/manage-cache). A retained local cache avoids more traffic than a CDN hit.', '',
    'The [Firebase pricing page](https://firebase.google.com/pricing) lists Remote Config request charges beyond 100,000 daily fetches, effective September 1, 2026. This implementation adds no Remote Config fetch loop. [Spend-cap documentation](https://firebase.google.com/docs/projects/billing/spend-caps) lists AI Logic, App Hosting, Functions and Extensions; classic Hosting is not included. Caps can overshoot during reporting delays. Budget alerts notify and do not stop services. No budget, quota or billing configuration was changed.', '',
    'For weather, `functions/src/index.ts` handles one primary forecast refresh with current, hourly and daily One Call 4.0 endpoints. Additional pages, alert-detail requests, failed attempts and fallback endpoints can add calls. The [One Call 4.0 documentation](https://openweathermap.org/api/one-call-4) describes six endpoint families, per-page billing, 10-minute provider updates and a default 2,000-call daily setting. This feature does not alter that setting. The [OpenWeather pricing page](https://openweathermap.org/price) lists 1,000 daily calls free, then $0.0015/call; subscriptions and other APIs have separate terms.', '',
    'Illustrative 30-day weather workload: four fresh app forecast refreshes per installation per day, no cache hits or failures, three upstream calls per refresh. Dollar column assumes every primary attempt is a billed One Call 4.0 call before allowances; it is not the owner\'s actual spend.', '',
    '| Active installations | App forecast refreshes / 30d | Primary upstream calls / 30d | Gross One Call USD | Added roast weather calls |',
    '|---:|---:|---:|---:|---:|']
for n in [10000,100000,1000000]:
    lines.append(f'| {n:,} | {120*n:,} | {360*n:,} | ${360*n*.0015:,.2f} | 0 |')
lines += ['', 'Actual backend cost also needs cache-hit ratio, endpoint mix, billed plan, deployment region, CPU/memory/duration, requests and account invoices. A read-only CLI check confirmed billing for the intended project is enabled. Budget listing failed because the Cloud Billing Budget API is disabled; existing budgets, spend caps, service quotas and actual spend therefore remain unverified. No API was enabled and no billing setting was changed. Recommended alert thresholds, once the owner sets a monetary budget, are 50%, 80%, 100% and forecasted 100%; inspect service quotas independently. Do not disable billing for the whole production project to contain humor traffic.', '']
output=root / 'docs/roasts/COST_REPORT.md'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text('\n'.join(lines))
print(output)
