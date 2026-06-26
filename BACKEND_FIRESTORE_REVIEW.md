# Backend and Firestore Review

Repository: `grumpy_skies`  
Firebase project mentioned by user: `wingman-interactive-live`  
Review date: 2026-06-17

## 1. Executive summary

`grumpy_skies` is currently a Flutter/Dart weather app with a small TypeScript Cloud Functions scaffold. At the time of this review, the app was still sample-data first: it used fake repositories, bundled demo coordinates, local `SharedPreferences`, placeholder radar UI, and no Flutter Firebase SDK packages.

That is good news for cost and safety. I found no client Firestore reads, writes, listeners, streams, queries, committed weather API keys, Firebase config files, or direct weather API calls in the Flutter app. The only backend code is a Functions v2 health endpoint that binds the `OPENWEATHER_API_KEY` secret and returns a non-secret JSON health response.

The safest backend plan is:

- Keep basic weather reads out of Firestore clients entirely.
- Use Cloud Functions as the weather API proxy and secret boundary.
- Use shared backend weather cache documents keyed by provider, rounded location/geohash, forecast kind, and time bucket.
- Keep client local cache as the first line of defense.
- Store only durable user preferences, saved locations, notification settings, device tokens, feedback, and optional entitlement mirrors in Firestore.
- Use Remote Config, bundled JSON/assets, Firebase Analytics, Crashlytics, Cloud Logging, Cloud Storage/CDN, and local storage instead of Firestore wherever those are cheaper or safer.
- Do not use the legacy live Firestore collections from `wingman-interactive-live`. Do not migrate or delete them. If this live project must host Grumpy Skies, use namespaced collections and emulator-tested rules.

The app can be hilarious without making Firestore expensive: bundle most persona and roast content, use Remote Config for weights and feature gates, generate fresh copy locally from weather condition tags, and reserve Firestore for rare durable user data.

## 2. Current repo findings

### Stack inventory

- App framework: Flutter.
- App language: Dart.
- Routing/state: `go_router`, `provider`.
- Local storage: `shared_preferences`.
- Network dependency: `http`, but no live weather HTTP client is wired yet.
- Backend: Firebase Cloud Functions v2, TypeScript, Node 20.
- Functions dependencies: `firebase-admin`, `firebase-functions`.
- Firebase app packages in Flutter: none found.
- Firestore rules/index files: none found in this repo.
- Firebase project binding: no `.firebaserc` found in this repo.
- Firebase platform config files: no `firebase_options.dart`, `google-services.json`, or `GoogleService-Info.plist` found in this repo.

### Firebase service wiring

| Service | Current status |
| --- | --- |
| Firebase Auth | Not wired in Flutter or functions routes. |
| Firestore | Not wired in Flutter. Admin SDK is present through Functions dependencies but not used. |
| Cloud Functions | Wired as a skeleton in `functions/src/index.ts`. |
| FCM | Not wired. No `firebase_messaging`, token storage, or notification functions. |
| Remote Config | Not wired. `lib/config/weather_runtime_config.dart` has local defaults intended to move to Remote Config later. |
| Crashlytics | Not wired. |
| Analytics | Not wired. |
| App Check | Not wired. Do not enforce yet. |
| Hosting | Not configured in `firebase.json`. |
| Emulator Suite | Functions `serve` script exists, but `firebase.json` does not yet declare emulator ports. |

### Important existing files

- `pubspec.yaml`: Flutter dependencies only, no Firebase packages.
- `firebase.json`: Functions source only. Ignores `.secret.local` and Firebase debug logs.
- `functions/src/index.ts`: Initializes Firebase Admin, defines `OPENWEATHER_API_KEY`, exports `weatherBackendHealth`.
- `functions/package.json`: Has `deploy`, `serve`, `shell`, and `logs` scripts.
- `README.md`: Correctly says weather credentials must stay out of the Flutter app and should live in Secret Manager.
- `lib/main.dart`: Injects `FakeWeatherRepository` and `FakeRoastRepository`.
- `lib/repositories/weather_repository.dart`: Good abstraction boundary for real weather later.
- `lib/services/weather_api_service.dart`: Provider abstraction placeholder.
- `lib/services/cache_service.dart`: Local weather cache helper, currently not wired into the repository.
- `lib/repositories/shared_preferences_settings_repository.dart`: Local settings persistence.
- `lib/features/progression/services/xp_service.dart`: Local XP/streak persistence and a local app-open update.
- `lib/config/weather_runtime_config.dart`: Local defaults for provider, TTLs, radar config, and rounding precision.

### Package and app ID mismatches

- Desired package/application ID mentioned by the user: `com.daymakerweather.app`.
- Android currently uses `com.example.grumpy_skies` in `android/app/build.gradle.kts`.
- Android `MainActivity.kt` package is `com.example.grumpy_skies`.
- iOS bundle identifier is `com.example.grumpySkies`.
- Web manifest and title still use `grumpy_skies`.
- Flutter app title is `DayMaker`.

Do not change those until the Firebase project/app registration is chosen. They are exactly the kind of mismatch that can create accidental Firebase config drift.

### Old app references

Inside `grumpy_skies`, I found no references to old Firestore collections such as `games`, `questions`, `soloScores`, `topics`, or `triviaPacks`. The only hit related to games is an ordinary UI label for mini-games.

The workspace has a separate sibling project, `brain_duel`, with trivia/Firebase code. I did not modify or depend on that project. The risk is not repo code leakage inside `grumpy_skies`; the risk is the shared live Firebase project containing old data and possibly old rules.

## 3. Existing Firebase and Firestore references

Direct Firebase references in `grumpy_skies`:

- `firebase.json`
- `functions/package.json`
- `functions/package-lock.json`
- `functions/src/index.ts`
- `README.md`
- `lib/config/weather_runtime_config.dart`
- `README_DAYMAKER_UI.md`

Direct Firestore reads/writes/listeners found in app code:

- None.

Direct weather API calls from client:

- None.

Committed secrets or API keys:

- No actual weather provider key found.
- No Firebase platform config files found.
- No service account files found.
- `firebase-debug.log` exists locally, is ignored, and is untracked. It contains a local Firebase login URL, so keep it out of commits.

Polling, listeners, or runaway write risks:

- No Firestore listeners or background polling loops found.
- `HomePage` uses a short local `Timer` for roast cooldown only.
- `XpService.create()` calls `markAppOpened()` and writes XP/streak data to `SharedPreferences`. Keep this local. Do not move app-open streak writes to Firestore.

Location handling:

- Current screens use fixed bundled demo coordinates.
- No geolocation dependency found.
- No Android release location permissions found.
- No iOS location usage strings found.
- `CacheService` would key local weather cache by lat/lon rounded to 3 decimals if wired.
- `WeatherRuntimeConfig.weatherRoundLatLonPrecision` says 2 decimals, which is better for shared backend cache and privacy.

## 4. Risks with `wingman-interactive-live`

Treat `wingman-interactive-live` as live production.

Primary risks:

- It appears to contain old app data from another project.
- A future deploy could accidentally target the live project because this repo has no `.firebaserc` project alias.
- `functions/package.json` includes a deploy script. That script is normal, but dangerous if the active Firebase CLI project is live.
- Replacing live Firestore rules would likely break old collections or expose data if done without a full legacy rules audit.
- Reusing `users/{uid}` in this live project could collide conceptually with old app users.
- Using high-cardinality location cache keys in the live Firestore would create lasting data and cost noise.

Recommended safety stance:

1. Prefer a new Firebase project for Grumpy Skies, plus a dev/staging project.
2. If `wingman-interactive-live` must be used, start with emulator-only work and namespaced Grumpy Skies paths.
3. Do not delete, migrate, seed, or inspect live data from scripts in this repo.
4. Do not deploy functions, rules, indexes, hosting, App Check enforcement, or billing changes from this pass.
5. Before any future deploy, add explicit project aliases and CI guardrails so `firebase deploy` cannot hit the wrong target by accident.

## 5. Recommended backend architecture

### Recommended flow

1. Client starts with local cached weather and local settings.
2. Client requests location permission only when needed.
3. Client rounds coordinates before backend requests, for example 2 decimal lat/lon or geohash precision 5.
4. Client calls a Cloud Function such as `getWeather`.
5. Function validates request, normalizes the cache key, and checks a shared cache.
6. If cache is fresh, return normalized weather.
7. If cache is stale, acquire a short refresh lease, call the provider, normalize response, write one shared cache doc, and return it.
8. If provider fails, return stale cached data when it is still safe to show.
9. Client stores the returned bundle in local cache with freshness/staleness metadata.
10. Firestore stores only durable user data and backend-owned cache/control data.

### Backend components

- `getWeather`: HTTPS or callable function returning current, hourly, daily, alert summary, and metadata.
- `getRadarMetadata`: returns frame timestamps, safe tile templates, attribution, and provider metadata. Do not store radar tiles in Firestore.
- `registerDevice`: authenticated callable to register/update FCM token and coarse alert regions.
- `updateNotificationPrefs`: authenticated callable or direct user doc update for preferences.
- `submitFeedback`: callable to create a small feedback doc with rate limiting.
- `scheduledAlertPoll`: scheduled function for active alert regions only.
- `providerStatus`: internal health/circuit breaker state, preferably in memory first and Firestore only if needed.

### Client components

- `BackendWeatherRepository` implementing existing `WeatherRepository`.
- `WeatherBackendClient` wrapping Functions/HTTP calls.
- `LocalWeatherCache` replacing or extending `CacheService`.
- `LocationService` for permission, one-shot location, and coordinate rounding.
- `RemoteConfigService` for feature gates, provider choice, TTLs, and content version.
- `NotificationService` for FCM permission, topic/device registration, and local notification settings.
- `AnalyticsService` using Firebase Analytics, not Firestore.
- `CrashReportingService` using Crashlytics.

### Auth model

- Basic weather should not require a permanent account.
- Use anonymous auth when the user needs cloud-synced saved locations, notification preferences, device registration, feedback, or subscriptions.
- Allow upgrade from anonymous to Apple/Google/email later.
- Firestore client rules should require `request.auth != null` for user-owned durable data.

## 6. Recommended Firestore schema

Best clean-project paths are shown below. If this must coexist inside `wingman-interactive-live`, use a Grumpy Skies namespace such as `apps/grumpySkies/...` or prefixed collections such as `grumpyUsers`, `grumpyWeatherCache`, and `grumpyFeedback` to avoid legacy collisions.

### `users/{uid}`

Purpose: Minimal account/profile/preferences root. Do not write on every app launch.

Example:

```json
{
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp",
  "schemaVersion": 1,
  "defaultUnits": {
    "temperature": "f",
    "wind": "mph",
    "pressure": "inHg"
  },
  "selectedPersonaId": "karen",
  "personaIntensity": 2,
  "homeLocationId": "home",
  "privacy": {
    "storeExactLocation": false,
    "locationPrecision": "geohash5"
  },
  "entitlementTier": "free"
}
```

Read frequency: 0 for local-only users; otherwise once after auth/session sync.  
Write frequency: only when durable preferences change.  
Owner/security: user can read/update own safe preference fields. Server owns entitlement fields.  
Indexes: none beyond default single-field indexes.  
Alternative: keep all settings in `SharedPreferences` until cross-device sync is needed.

Use `users/{uid}` only in a clean Grumpy Skies Firebase project. In the current live project, avoid this path unless legacy `users` data has been fully separated.

### `users/{uid}/savedLocations/{locationId}`

Purpose: Cloud-synced saved locations.

Example:

```json
{
  "label": "Home",
  "placeName": "Chicago, IL",
  "roundedLat": 41.88,
  "roundedLon": -87.63,
  "geohash": "dp3wj",
  "timezone": "America/Chicago",
  "countryCode": "US",
  "regionKey": "us-il-chicago",
  "isHome": true,
  "sortOrder": 0,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

Read frequency: when saved-location screen opens, after auth sync, or from local mirror cache.  
Write frequency: add/edit/delete saved location only.  
Owner/security: user owns only their subcollection.  
Indexes: no composite index initially; optional order by `sortOrder`.  
Alternative: local storage only for anonymous users.

Do not store exact GPS coordinates unless the user explicitly opts in and there is a clear product reason.

### `users/{uid}/notificationPrefs/{prefId}`

Purpose: Durable alert preferences, not per-notification logs.

Example:

```json
{
  "enabled": true,
  "alertTypes": ["severe", "precip_start", "daily_summary"],
  "quietHours": {
    "enabled": true,
    "startLocal": "22:00",
    "endLocal": "07:00"
  },
  "regions": ["dp3wj", "9q8yy"],
  "updatedAt": "serverTimestamp"
}
```

Read frequency: once when notification settings load.  
Write frequency: only when preferences change.  
Owner/security: user can read/write own prefs. Backend validates topic subscriptions.  
Indexes: none.  
Alternative: store local-only notification prefs until FCM is added.

### `users/{uid}/devices/{deviceId}`

Purpose: FCM token/device metadata for direct notifications when topics are insufficient.

Example:

```json
{
  "platform": "ios",
  "fcmToken": "sensitive-token-value",
  "appVersion": "1.0.0",
  "locale": "en-US",
  "regionTopics": ["wx_alert_dp3wj"],
  "notificationsEnabled": true,
  "lastRegisteredAt": "serverTimestamp",
  "expiresAt": "serverTimestamp"
}
```

Read frequency: almost never by client.  
Write frequency: token refresh, preference change, app reinstall, or periodic refresh no more than monthly.  
Owner/security: prefer backend-only writes through callable functions. Clients should not list all tokens.  
Indexes: none initially.  
Alternative: use FCM topic subscription without token docs for the first alert MVP.

### `weatherCache/{cacheKey}`

Purpose: Backend-owned shared normalized weather cache. Not user data.

Example:

```json
{
  "provider": "openweather",
  "kind": "bundle",
  "cacheKey": "v1:openweather:bundle:dp3wj:2026-06-17T23:40Z",
  "geohash": "dp3wj",
  "roundedLat": 41.88,
  "roundedLon": -87.63,
  "bucketStart": "2026-06-17T23:40:00Z",
  "freshUntil": "2026-06-17T23:50:00Z",
  "staleUntil": "2026-06-18T00:50:00Z",
  "refreshingUntil": null,
  "payloadVersion": 1,
  "payload": {
    "current": {},
    "hourly": [],
    "daily": [],
    "alerts": []
  },
  "providerFetchedAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

Read frequency: by Cloud Functions only, at most one doc read per backend weather call when in-memory/CDN cache misses.  
Write frequency: by Cloud Functions only when stale/missing.  
Owner/security: clients denied. Admin SDK only.  
Indexes: none; direct document lookups only. Enable TTL later on `staleUntil` or `expiresAt` after emulator testing.  
Alternative: in-memory cache, Cloud CDN, Cloud Storage JSON, or Memorystore if traffic grows.

### `weatherAlerts/{regionKey}` or `alertRegions/{regionKey}`

Purpose: Backend-owned current alert state and FCM topic metadata.

Example:

```json
{
  "regionKey": "dp3wj",
  "activeAlertIds": ["nws-20260617-abc"],
  "lastPolledAt": "serverTimestamp",
  "nextPollAfter": "serverTimestamp",
  "topic": "wx_alert_dp3wj",
  "subscriberEstimate": 128,
  "expiresAt": "serverTimestamp"
}
```

Read frequency: scheduled functions only.  
Write frequency: alert polling and subscription count changes.  
Owner/security: clients denied.  
Indexes: maybe `nextPollAfter` for scheduled polling if querying active regions.  
Alternative: FCM topics plus provider polling without Firestore until scale requires region bookkeeping.

### `appContent/personas` and `roastTemplates`

Recommendation: Avoid Firestore for launch.

Use bundled JSON/assets for:

- Persona definitions.
- Roast templates.
- Weather condition mappings.
- Safety suppression rules.
- Meme template defaults.

Use Remote Config for:

- Enabled personas.
- Content bundle version.
- Intensity defaults.
- Template weights.
- Feature gates.
- A/B experiment assignment.

If Firestore is needed later, use a small number of versioned bundle docs, not one document per line:

```json
{
  "version": "2026-06-17-v1",
  "minAppVersion": "1.0.0",
  "personas": [],
  "templateManifestUrl": "gs://or-https-url",
  "updatedAt": "serverTimestamp"
}
```

### `featureFlags`

Recommendation: Do not use Firestore. Use Remote Config.

### `feedback/{feedbackId}`

Purpose: Optional user feedback, created through a callable function with rate limiting.

Example:

```json
{
  "uid": "anonymous-or-real-uid",
  "category": "forecast_quality",
  "message": "The rain timing was off.",
  "appVersion": "1.0.0",
  "platform": "android",
  "createdAt": "serverTimestamp",
  "status": "new"
}
```

Read frequency: admin only.  
Write frequency: rare, user-initiated.  
Owner/security: prefer function-only writes; clients denied direct reads.  
Indexes: optional `status, createdAt` for admin tools.  
Alternative: support email or external helpdesk at launch.

### `subscriptions/{uid}` or `users/{uid}/entitlements/current`

Purpose: Server-owned entitlement cache from App Store/Play/RevenueCat/Stripe.

Example:

```json
{
  "tier": "premium",
  "source": "revenuecat",
  "expiresAt": "2026-07-17T00:00:00Z",
  "lastVerifiedAt": "serverTimestamp"
}
```

Read frequency: once on app start after auth, then local cache.  
Write frequency: webhook or verification changes only.  
Owner/security: user can read own entitlement; only backend can write.  
Indexes: none.  
Alternative: custom claims or RevenueCat SDK cache.

### Legacy live collections

Existing live collections such as `games`, `questions`, `soloScores`, `topics`, `triviaPacks`, and legacy `users` should not be used, migrated, deleted, or overwritten by Grumpy Skies.

## 7. Data that should NOT be stored in Firestore

Do not store:

- Every app launch.
- Every weather view.
- Every refresh tap.
- Every location lookup.
- Raw provider responses per user.
- Weather responses under `users/{uid}`.
- Exact GPS history.
- High-volume analytics events.
- Notification impressions or per-device send logs.
- Radar tile images or frames.
- Map layer tiles.
- Crash/error logs.
- Ad impressions or mediation events.
- Every generated roast.
- Every meme preview edit.
- Large persona/template libraries as many tiny documents.
- Static content that can be bundled, hosted in Cloud Storage/CDN, or controlled with Remote Config.
- Any high-cardinality, high-frequency write where Analytics, Crashlytics, Cloud Logging, local storage, or backend cache is a better fit.

## 8. Weather cache strategy

### Provider-agnostic pattern

In Functions, define provider adapters behind a small interface:

```ts
interface WeatherProvider {
  getWeatherBundle(request: WeatherRequest): Promise<NormalizedWeatherBundle>;
  getAlerts(request: AlertRequest): Promise<NormalizedAlert[]>;
  getRadarMetadata(request: RadarRequest): Promise<RadarMetadata>;
}
```

Then keep provider-specific parsing in adapters:

- `OpenWeatherProvider`
- `WeatherKitProvider`
- `NwsProvider`
- `TomorrowProvider`
- Future provider adapters as needed

The Flutter app should talk to `WeatherRepository`, not to provider SDKs or provider URLs.

### Cache key

Use normalized keys that do not include `uid`:

```text
v1:{provider}:{kind}:{geoKey}:{timeBucket}
```

Examples:

- `v1:openweather:bundle:dp3wj:2026-06-17T23:40Z`
- `v1:openweather:alerts:dp3wj:2026-06-17T23:45Z`
- `v1:openweather:radar-meta:us:2026-06-17T23:45Z`

Guidance:

- Store provider-normalized units, not user display units, so Fahrenheit/Celsius does not multiply cache keys.
- Use rounded lat/lon or geohash, not exact lat/lon.
- Start with 2 decimal rounding or geohash precision 5 for most weather.
- Use provider zones/counties for alerts when available, because alert boundaries matter.
- Include payload version so future migrations can coexist safely.

### TTLs

Recommended starting TTLs:

| Data type | Fresh TTL | Max stale if provider fails | Notes |
| --- | ---: | ---: | --- |
| Current weather | 5 to 10 min | 60 min | Short enough to feel live, long enough to share. |
| Minute precipitation | 5 to 10 min | 30 min | Only if provider supports it. |
| Hourly forecast | 20 to 30 min | 6 hours | Cache by geohash/time bucket. |
| Daily forecast | 2 to 6 hours | 24 hours | Usually does not need frequent refresh. |
| Alerts | 1 to 5 min active, 10 to 15 min quiet | 30 min | Safety copy should expose stale status. |
| Radar metadata | 5 min | 20 min | Store metadata only, not tiles. |
| Radar tiles | Provider/CDN TTL | Provider/CDN TTL | Do not store in Firestore. |

### Stampede prevention

Use a short refresh lease on the cache doc:

1. Function reads cache doc.
2. If fresh, return.
3. If stale and no active `refreshingUntil`, transactionally set `refreshingUntil = now + 20s`.
4. Winner calls provider and writes payload.
5. Losers return stale data if available or wait briefly and retry once.
6. If provider fails, winner clears lease and preserves stale payload.

### Provider failure behavior

Return:

- `isStale: true`
- `staleReason: "provider_error"` or `"rate_limited"`
- `providerFetchedAt`
- `freshUntil`
- safe user-facing fallback message

Do not hide stale data status from the UI. Severe alerts should degrade conservatively: if alert freshness cannot be confirmed, show a serious "check official sources" state instead of a joke.

### Rate limits

- Set per-provider timeouts.
- Use exponential backoff for repeated failures.
- Store `retryAfter` or provider circuit-breaker state if rate limits occur.
- Consider Cloud CDN or Cloud Run + in-memory cache if function traffic becomes high.
- Keep direct provider calls proportional to unique rounded locations and TTL buckets, not total users.

## 9. Notification strategy

Leanest architecture:

1. Use local notifications for daily funny nudges when possible. They do not need Firestore.
2. Use FCM topics for severe/weather region alerts.
3. Use coarse region topics, such as provider zone, county, or geohash 5.
4. Store FCM token/device data only when direct targeting is required.
5. Store notification preferences only when the user changes them.
6. Do not write one Firestore doc per notification sent.
7. Do not scan all users to decide who gets an alert.

Recommended FCM topic pattern:

```text
wx_alert_{regionKey}
wx_daily_{regionKey}
```

Backend flow:

- Client determines coarse region from rounded location.
- Client signs in anonymously if cloud notification prefs are needed.
- Client or callable function subscribes the device to region topics.
- Scheduled function polls provider alerts for active regions.
- Function sends one FCM message to the region topic.
- Function writes at most one dedupe doc per `alertId + regionKey`, not per user.

Preference handling:

- Severe alerts: topic messages can be high priority and region based.
- Daily/funny nudges: prefer local notification scheduling or topic sends with broad controls.
- Quiet hours and user-specific filtering are expensive with pure topic fanout. For non-critical messages, handle them locally. For critical weather alerts, safety should win.

## 10. Fun and personality content strategy

Make the personality system cheap by making it mostly local and versioned.

Bundle in the app:

- Persona IDs, names, base tone tags, and default availability.
- Roast template banks by condition, temperature band, humidity, wind, precipitation, UV, air quality, time of day, and alert state.
- Safety suppression rules for severe weather.
- Meme template defaults.
- Generated persona art and background art.

Use Remote Config for:

- Enabled personas.
- Default persona.
- Persona weights.
- Roast intensity.
- Content bundle version.
- Feature toggles.
- A/B experiments.
- Kill switches for a template category.
- Monetization gates.

Use Firestore only if:

- Admin-authored content must update between app releases and Remote Config limits are too tight.
- Feedback moderation or user reports are needed.
- Premium entitlement state must be mirrored.

Freshness without Firestore reads:

- Select templates locally using a deterministic seed such as date + persona + weather condition + coarse region.
- Rotate templates by content version and day.
- Use Remote Config weights to change the feel without fetching many documents.
- Keep recent roast IDs in local storage to avoid repeats.
- Tone down or suppress jokes when active severe alerts exist.

A/B testing:

- Use Firebase Remote Config experiments and Firebase Analytics events.
- Do not store experiment assignment or every impression in Firestore.

## 11. Security rules draft

Do not apply these rules to `wingman-interactive-live` without a full legacy rules audit. This is a draft for emulator testing or a clean Grumpy Skies project.

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return signedIn() && request.auth.uid == uid;
    }

    function hasOnlyKeys(allowed) {
      return request.resource.data.keys().hasOnly(allowed);
    }

    function isRoundedCoordinate(value) {
      return value is number;
    }

    match /users/{uid} {
      allow read: if isOwner(uid);

      allow create, update: if isOwner(uid)
        && hasOnlyKeys([
          'createdAt',
          'updatedAt',
          'schemaVersion',
          'defaultUnits',
          'selectedPersonaId',
          'personaIntensity',
          'homeLocationId',
          'privacy'
        ]);

      allow delete: if isOwner(uid);

      match /savedLocations/{locationId} {
        allow read: if isOwner(uid);

        allow create, update, delete: if isOwner(uid)
          && hasOnlyKeys([
            'label',
            'placeName',
            'roundedLat',
            'roundedLon',
            'geohash',
            'timezone',
            'countryCode',
            'regionKey',
            'isHome',
            'sortOrder',
            'createdAt',
            'updatedAt'
          ])
          && isRoundedCoordinate(request.resource.data.roundedLat)
          && isRoundedCoordinate(request.resource.data.roundedLon);
      }

      match /notificationPrefs/{prefId} {
        allow read, create, update, delete: if isOwner(uid)
          && hasOnlyKeys([
            'enabled',
            'alertTypes',
            'quietHours',
            'regions',
            'updatedAt'
          ]);
      }

      match /devices/{deviceId} {
        allow read, write: if false;
      }

      match /entitlements/{document=**} {
        allow read: if isOwner(uid);
        allow write: if false;
      }
    }

    match /weatherCache/{cacheKey} {
      allow read, write: if false;
    }

    match /weatherAlerts/{regionKey} {
      allow read, write: if false;
    }

    match /appContent/{document=**} {
      allow read, write: if false;
    }

    match /feedback/{feedbackId} {
      allow read, update, delete: if false;

      allow create: if signedIn()
        && hasOnlyKeys([
          'uid',
          'category',
          'message',
          'appVersion',
          'platform',
          'createdAt',
          'status'
        ])
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.message is string
        && request.resource.data.message.size() <= 2000;
    }

    match /subscriptions/{uid} {
      allow read: if isOwner(uid);
      allow write: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

For a shared live project, replace these paths with namespaced Grumpy Skies paths and preserve any legacy app rules.

## 12. Cost model with formulas

No exact vendor pricing is included here. Apply current Firebase, Cloud Functions, FCM, and provider pricing when making budget decisions.

### Assumptions

- Average app opens per user per day: 3.
- Average weather refresh attempts per user per day: 4.
- Client local cache hit rate: 70 percent.
- Backend weather calls per user per day: `4 * (1 - 0.70) = 1.2`.
- Function weather calls per day: `DAU * 1.2`.
- Firestore weather cache reads: assume one cache doc read per backend weather call.
- Weather cache writes: one cache doc write per provider fetch.
- Firestore reads per app open: 0 by default for local-only users; optional account sync can add 1 user doc read plus saved-location reads.
- Firestore writes per app open: 0.
- Saved location add/update/delete: 1 doc write.
- Saved location list read: 1 read per saved location when syncing/opening that list.
- Notification preference change: 1 preference write, plus 1 device/topic update write if needed.
- Notification send logging: 0 per user; at most 1 dedupe/region doc per alert.

### Weather traffic estimate

| DAU | Function weather calls/day | Assumed backend cache hit | Firestore cache reads/day | Provider calls and cache writes/day |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 1,200 | 85% | 1,200 | 180 |
| 10,000 | 12,000 | 92% | 12,000 | 960 |
| 50,000 | 60,000 | 96% | 60,000 | 2,400 |
| 250,000 | 300,000 | 98% | 300,000 | 6,000 |

Formula:

```text
backendWeatherCalls = DAU * weatherRefreshAttemptsPerUser * (1 - clientLocalCacheHitRate)
providerCalls = backendWeatherCalls * (1 - backendCacheHitRate)
weatherCacheReads = backendWeatherCalls
weatherCacheWrites = providerCalls
```

### Durable user data estimate

If 20 percent of DAU use cloud sync and each synced user reads their profile once per day:

```text
userProfileReads = DAU * 0.20
```

If each synced user has 2 saved locations and opens the saved-location manager once every 10 days:

```text
savedLocationReads = DAU * 0.20 * 2 * 0.10
```

If 1 percent of DAU changes notification preferences per day:

```text
notificationPrefWrites = DAU * 0.01
```

These are tiny compared with weather refresh traffic, which is why weather cache design matters most.

### Biggest cost risks

- Client-side Firestore listeners on weather cache documents.
- Writing a document on every app launch.
- Writing a document for every weather view.
- Writing per-user weather snapshots.
- Cache keys that include exact lat/lon, creating low cache reuse.
- Scanning all users/devices for weather alerts.
- Writing notification send/impression docs per user.
- Storing radar tiles in Firestore.
- Using Firestore as analytics.
- Fetching dozens of persona/template documents on startup.

## 13. Phased implementation plan

### Phase 0: Safety cleanup and old app reference audit

- Keep all work emulator/local.
- Confirm whether Grumpy Skies gets a new Firebase project.
- If using `wingman-interactive-live`, document legacy collections and rules before any deploy.
- Add deploy guardrails and explicit project aliases later, but do not deploy now.
- Decide final package IDs: likely `com.daymakerweather.app`.
- Decide whether the product name is `Grumpy Skies` or `DayMaker` across app title, bundle IDs, and docs.

### Phase 1: Firebase emulator setup and backend skeleton

- Add emulator config for Functions, Firestore, Auth, and optionally UI.
- Add local demo project instructions.
- Add tests for functions without live credentials.
- Keep `OPENWEATHER_API_KEY` in Secret Manager or `.secret.local` for emulator only.
- Add CI/build checks that never deploy.

### Phase 2: WeatherRepository, Cloud Function proxy, and cache

- Implement `BackendWeatherRepository` in Flutter.
- Implement `getWeather` function.
- Add provider adapter interface and first OpenWeather adapter.
- Normalize provider response to existing `WeatherBundle`/`WeatherSnapshot`.
- Add shared `weatherCache` with TTL, stale return, and refresh lease.
- Wire local cache before backend call.

### Phase 3: Minimal Firestore schema and rules

- Add draft `firestore.rules` and tests.
- Add `firestore.indexes.json`, likely empty at first.
- Deny client access to backend cache and alerts.
- Allow only authenticated users to read/write their own minimal preference docs.
- Test with anonymous auth in emulator.

### Phase 4: Saved locations and preferences

- Add location permission flow.
- Store local recent/current location without exact Firestore persistence.
- Add saved locations under user only when cloud sync is enabled.
- Mirror saved locations locally for startup speed.
- Avoid reads on every tab switch.

### Phase 5: FCM weather alerts

- Add Firebase Messaging.
- Add device registration callable.
- Add region topic strategy.
- Add alert polling by active region.
- Send topic notifications for severe alerts.
- Avoid per-user notification logs.

### Phase 6: Fun/personality system

- Move persona/template banks to bundled JSON/assets.
- Add Remote Config knobs for enabled personas, intensity, weights, and content version.
- Add safety suppression for severe weather.
- Add local recent-template memory to avoid repetitive roasts.
- Use Analytics/Remote Config experiments for A/B testing, not Firestore.

### Phase 7: Cost monitoring, budgets, dashboards, and guardrails

- Add Firebase budget alerts.
- Track function invocations, provider calls, cache hit rate, stale returns, and error rate.
- Use Cloud Logging metrics, not Firestore event docs.
- Add provider quota alarms.
- Add Remote Config kill switches for radar, weather provider, and non-critical notifications.
- Review Firestore usage before enabling any real-time listener.

## 14. Exact file change list for a later implementation pass

Do not change these yet unless implementation is requested.

Likely files to create:

- `BACKEND_FIRESTORE_REVIEW.md` - this report.
- `.firebaserc` - only after project strategy is confirmed.
- `firestore.rules`
- `firestore.indexes.json`
- `functions/src/weather/types.ts`
- `functions/src/weather/provider.ts`
- `functions/src/weather/openWeatherProvider.ts`
- `functions/src/weather/cache.ts`
- `functions/src/weather/getWeather.ts`
- `functions/src/alerts/pollAlerts.ts`
- `functions/src/notifications/registerDevice.ts`
- `functions/src/feedback/submitFeedback.ts`
- `functions/test/*.test.ts`
- `lib/repositories/backend_weather_repository.dart`
- `lib/services/weather_backend_client.dart`
- `lib/services/local_weather_cache.dart`
- `lib/services/location_service.dart`
- `lib/services/remote_config_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/analytics_service.dart`
- `lib/services/crash_reporting_service.dart`
- `lib/services/entitlement_service.dart`
- `assets/content/personas.v1.json`
- `assets/content/roast_templates.v1.json`
- `docs/backend_architecture.md`
- `docs/firebase_emulator_runbook.md`

Likely files to modify:

- `pubspec.yaml` - add Firebase, geolocation, notification packages only when needed.
- `firebase.json` - add emulator config, Firestore rules/index references, and guardrails.
- `functions/package.json` - add test/lint scripts and safer local scripts.
- `functions/src/index.ts` - export real functions.
- `lib/main.dart` - initialize Firebase and swap fake repositories for backend-backed implementations behind feature flags.
- `lib/config/weather_runtime_config.dart` - align defaults with Remote Config keys.
- `lib/services/cache_service.dart` - replace or adapt to current cache precision and freshness metadata.
- `lib/repositories/weather_repository.dart` - add stale/offline metadata if needed.
- `lib/models/weather_models.dart` and `lib/models/daymaker_models.dart` - add alert/provider/cache metadata carefully.
- `lib/features/forecast/forecast_screen.dart` - remove hard-coded demo coordinates once location service exists.
- `lib/pages/home_page.dart` and `lib/pages/burns_page.dart` - retire or align older compatibility pages.
- `android/app/build.gradle.kts` - final application ID and Firebase Gradle plugin.
- `android/app/src/main/AndroidManifest.xml` - location/notification permissions when features are wired.
- `android/app/src/main/kotlin/.../MainActivity.kt` - package path if application ID changes.
- `ios/Runner.xcodeproj/project.pbxproj` - final bundle ID.
- `ios/Runner/Info.plist` - location/notification permission copy when features are wired.
- `web/manifest.json` and `web/index.html` - final app name/title.
- `README.md` - emulator-first Firebase setup and no-live-deploy warning.

Firebase platform config files to create later only after project choice:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

These are not weather provider secrets, but they bind the app to a Firebase project, so do not add them casually to this live setup.

## 15. Open questions

1. Should Grumpy Skies use a brand-new Firebase project instead of `wingman-interactive-live`?
2. Is the public product name `Grumpy Skies`, `DayMaker`, or both?
3. Is `com.daymakerweather.app` the final Android application ID and iOS bundle identifier?
4. Should anonymous auth be enabled for all users, or only when cloud sync/notifications are enabled?
5. Which weather provider is the first production target: OpenWeather, WeatherKit, NWS, AccuWeather, or another provider?
6. Which countries/regions need launch support?
7. How precise should location be for normal forecasts: 2 decimal lat/lon, geohash 5, provider grid, or user-selectable?
8. Are severe weather alerts launch-critical, or should they follow current/hourly/daily weather?
9. Should saved locations sync across devices at launch, or remain local until accounts/premium exist?
10. Which monetization path is first: ads, premium subscription, one-time unlock, affiliate/weather products, or a mix?
11. Should daily funny notifications be local-only at launch?
12. Do you want a backend implementation pass next, or a Firebase emulator/rules test pass first?
