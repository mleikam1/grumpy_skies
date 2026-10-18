# Optional static updates — disabled design only

The implementation uses bundled local JSON only. There is no guidance update client, manifest request, remote content listener, background download, remote kill switch, or live update URL. This document is a future design, not an implemented or enabled feature. No Remote Config behavior is changed.

If separately authorized later, updates should consist of a tiny manifest and immutable compressed versioned content on static hosting/CDN. Keep the bundle as a permanent fallback. Do not use Firestore, Functions, an LLM, per-user generated copy, or a database for tips. Do not add polling to widget builds, app resumes, tip evaluation, navigation, or weather refresh.

## Future request budget and activation

Use an explicit disabled-by-default compile-time/build configuration. While disabled, create no network client and do not read remote settings. If the app later already has an approved cached Remote Config value, a disabled flag may be read from that cache without initiating a fetch; enabling delivery must remain a separately reviewed release change. A kill switch can stop future updates but must not be a dependency of local weather guidance.

When enabled, a process-wide single-flight coordinator may attempt one manifest check after the app is interactive, at most once per seven days. Persist the attempt timestamp before starting the request so failures, offline sessions, restarts, and concurrent widgets cannot retry-loop. A persistence failure prevents the attempt. A clock that moves backward does not bypass the throttle. No immediate retries or exponential retry timer: another automatic attempt waits for the next weekly eligibility window.

One eligible check sends at most one conditional manifest request. A valid unchanged version or HTTP 304 ends the attempt. Only a compatible new immutable version permits one content request. A failed manifest, timeout, rejected version, failed content download, or validation failure keeps the last good content/bundle without another request during that attempt. No URL probing, automatic alternative endpoints, version discovery scans, or redirect-following to unknown hosts.

Proposed hard limits, requiring future implementation and tests:

| Boundary | Proposed limit |
| --- | --- |
| Manifest response | 8 KiB maximum body |
| Pack response | 256 KiB maximum compressed bytes |
| Decompression | 1 MiB maximum expanded bytes; stream with a hard counter |
| Request time | 10 seconds per request; maximum two requests in one weekly attempt |
| Concurrent work | One attempt and at most one content download process-wide |
| Retained versions | Active validated pack, one last-good pack, bundled fallback |
| State writes | One attempted-check timestamp; one atomic activation only after full validation |

The manifest must allowlist schema version, content version, supported app version range, locale, immutable relative object path, compressed/expanded size, content SHA-256, and optional expiry. Never accept arbitrary executable code, redirects, additional domains, credentials, query parameters built from users, or executable rules from downloaded JSON. Use HTTPS on a reviewed owned host, validate the content hash, and assess signed manifests before rollout because a checksum fetched beside content does not independently establish authenticity.

Decode into a temporary location. Enforce size caps, UTF-8 and strict JSON parsing, duplicate-key rejection, known schema/IDs/fields/surfaces/guards, compiled mandatory prerequisites, text/placeholder budgets, and version compatibility. Run the complete catalog validator before release, and equivalent fail-closed validation on-device. Only then atomically replace a pointer to the complete version. A crash, malformed pack, unsupported field, new executable guard, decompression failure, or rollback leaves the active version intact. If active and last-good copies are unusable, load the bundle without repair fetching.

Keep request metadata to content version, locale, and supported app version as needed. Never include preferences, impressions, selected weather location, calendar/event data, timestamps of user activity, device identity, or user identifiers. Do not upload selection counts or content-view analytics. An update must not change the weather API/cache/radar/geocoding/calendar paths.

## Payload estimate, not a price quote

The actual current files are 104,112 bytes total, or 15,323 bytes when each is gzip-compressed independently. A future single-envelope pack would have its own measured serialization size; archive/envelope overhead and cross-file compression must be measured for the exact published artifact. These bundled files do not generate recurring content traffic on native app evaluation. A web app still obtains application assets through its ordinary app-loading/cache mechanism.

For illustration, 10,000 enabled installations making four weekly checks in 28 days would make at most 40,000 manifest requests. If every check saw a new compatible pack, there could also be 40,000 content requests. Using the current separate-gzip sum solely as a payload proxy gives 612,920,000 content bytes (about 584.5 MiB) before headers, TLS, manifest bodies, CDN behavior, or future envelope differences. With unchanged content, the content-download count is zero. At the proposed 8 KiB maximum, 40,000 manifest bodies would add no more than 327,680,000 bytes; normal manifests should be much smaller.

No current hosting free tier, Firebase quota, LLM price, CDN price, or monthly dollar estimate is asserted here. Pricing would require verifying the chosen provider's current official terms, region, request accounting, transfer behavior, and the final artifact before enabling delivery. The zero incremental network claim applies to local guidance evaluation; it is not a claim that the rest of the weather app or any future distribution is cost-free.
