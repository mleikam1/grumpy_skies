# Dependency and legacy runtime audit

This audit reads repository source and checked-in lockfiles for the contextual-guidance change. It is not a claim about a deployed Firebase environment, installed app binary, provider pricing, or latest package releases. No dependency installation, external service call, or deployment was performed for this audit.

## Locked dependencies

| Dependency | Locked version | Relevant role |
| --- | --- | --- |
| `http` | 1.6.0 | Existing weather/backend transport; not imported by guidance selection |
| `shared_preferences` | 2.5.3 | Existing device-local settings and bounded guidance history |
| `provider` | 6.1.5+1 | Existing app state integration |
| `timezone` | 0.10.1 | Existing local IANA/DST interpretation |
| `crypto` | 3.0.7 | Existing package; no network capability |
| `intl` | 0.20.2 | Existing localized display of supported facts and intervals |
| `geolocator` | 14.0.2 | Existing location capability; guidance does not initiate location requests |
| `go_router` | 14.8.1 | Existing navigation |
| `google_mobile_ads` | 9.1.0 | Existing independent monetization path |
| Backend `firebase-admin` | 12.7.0 | Existing Functions dependency |
| Backend `firebase-functions` | 6.6.0 | Existing weather/radar/geocoding HTTP routes |
| Backend `typescript` | 5.9.3 | Existing build dependency |

Versions above come from `pubspec.lock` and `functions/package-lock.json`, rather than the looser constraints in manifests. The Flutter lockfile requires Dart >=3.12.0 and Flutter >=3.44.0; these are compatibility constraints, not a measurement of the running SDK. `functions/package.json` specifies Node 20. The guidance addition does not require a new package or a lockfile change.

There is no Firebase client, Firestore client, Remote Config client, OpenAI SDK, or other LLM SDK in the Flutter lockfile. The backend manifest directly declares Firebase Admin and Firebase Functions; this does not imply that every transitive service capability is called. The inspected current guidance code imports local models, engine/adapter classes, Flutter assets/state, preferences, timezone, and formatting utilities. It has no HTTP client, database client, ad client, location client, or calendar repository import.

## Existing remote behavior and retired features

`lib/config/weather_runtime_config.dart` contains static app-side weather/radar defaults and a historical comment about possible future Remote Config. There is no executable Remote Config fetch or listener to change. Existing weather/backend and radar requests remain in their established clients and backend handlers. Guidance adds no route or content-fetch endpoint. Request counters used to demonstrate guidance off/on equivalence are instrumentation, not new request sources.

The current app has no roast/persona generator or runtime content updater. Remaining old names have compatibility or design roles: the targeted upgrade migration removes exact retired preference keys; old roast/persona routes redirect away from the retired experience; saved meme documents retain opaque legacy provenance; and shared weather/PlanCast styling still uses some historical identifiers. Old `assets/roasts`, persona source art, and `docs/roasts` evidence are repository history/source material rather than guidance assets. They are not activated by the new catalog. This change does not reintroduce those directories into the explicit Flutter asset declarations.

The guidance catalog is initialized from bundled assets. Parse failure suppresses optional guidance rather than fetching a repair. Preferences and impression history use separate device-local keys. Source review supports the intended zero incremental network boundary; runtime request-count evidence and the full validation results are recorded by the implementation's tests and final handoff, not inferred solely from an import scan.

No claims are made here about provider free tiers, remaining quotas, billing, or up-to-date SDK recommendations. Existing weather/radar/map/ad activity may still incur its normal costs. Optional future static updates remain a disabled architecture document only.
