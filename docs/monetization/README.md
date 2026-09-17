# Weather-first advertising

Implementation starts from `4f5632070a4ed785ba72cf72d29d0cb47fed982e`, including the merged local Meme Studio. The original checkout and its untracked `.firebase/` directory were preserved; work uses `feat/weather-first-ad-monetization` in a separate worktree. No deployment, billing, signing, project switch, store release, or production activation is authorized by this change.

## Architecture and boundaries

`lib/monetization/` separates logical placements, configuration, UMP consent, safety/route eligibility, native display/interstitial adapters, persistent interstitial policy, bundled editorial selection, display lifecycle, and reporting. `MonetizationController` observes existing weather safety but owns no weather repository and makes no weather requests. Startup begins after `runApp`; consent, SDK, storage, inventory and web script failures cannot become forecast errors. `AdModalObserver` only accounts for modal activity; it never shows an ad.

Production defaults are off. `AdConfig.fromEnvironment` is the executable local configuration; `assets/monetization/config.v1.json` documents its versioned defaults. There is no remote configuration endpoint and no claim of a remote kill switch. New runtime configuration must clamp to the policy service's immutable minimums/maximums. There are no per-impression Firestore reads/writes.

## Placements

| ID | Rule | Format |
| --- | --- | --- |
| `forecast_banner` | After current, precipitation and hourly content, before deeper breakdown; only fresh actual weather, alerts above | Fixed 320×50 if usable width is at least 320 px; 728×90 if at least 728 px; omit otherwise |
| `roasts_history_mrec` | After 4 substantial actual cards; existing sample-only screen remains suppressed | AdMob Banner `AdSize.mediumRectangle`, 300×250 |
| `fun_hub_mrec` | After actual fortune result and Meme Studio area; navigation-only hub suppressed | 300×250 |
| `meme_library_mrec` | After completed row containing filtered publisher template 6; requires at least 6; absent My Memes/editor/import/export | 300×250 |
| `fun_complete_interstitial` | Native only, after delivered successful saved/exported result and deliberate Done/Back to Fun | SDK interstitial |

One display per eligible content view. No home MREC, bottom banner, radar/alert/settings/onboarding/editor/error ads. A 320 px screen with normal page padding may not fit a 320 px creative; omission is intentional. No creative is scaled/cropped/covered. Labels and editorial text remain outside its exact bounds. The section requests once when visible, reserves loading space, defers failure collapse during touches/scrolling, and retires offscreen/background/hidden slots. No refresh timers. Automatic refresh must be disabled for every banner unit in AdMob before production readiness is acknowledged. SDK test inventory may have provider settings outside this repository; do not infer console refresh configuration from code.

## Explicit completion and frequency policy

Completion uses a local hash of document identity and canonical content revision, excluding save timestamps. Repeated unchanged exports do not increment it. Completion is recorded only after a successful result was painted; an export-button tap, reroll, cancelled share, failed save, navigation, or autosave does not count. Done first dismisses the result route and ends its full-screen operation. Then policy rechecks all gates and either shows a ready ad or navigates immediately. No late-loaded ad can appear after that opportunity.

Policy persists session count, actual shown history, distinct revision hashes, and caps. First session is ineligible. Minimums: 180 foreground seconds, 3 completions since the previous shown ad, and 300 seconds since the previous shown ad. Maximums: 1 per session and 3 per rolling 24 hours. A session survives process restart and short background absences; 30 minutes of inactivity begins a new session. Share/ad operations do not create a new session; background time never adds engagement. A monotonic clock measures foreground engagement. Runtime clock jumps and rollback fail conservatively; without a trusted time service, a wall-clock jump while the process is terminated cannot be authenticated. A pending presentation survives crashes as uncertainty, not a reported impression or a reset quota.

Preloading occurs only when already eligible on Fun, outside forecast/editor rendering. Prior ready inventory may be retained during modal operations but never presented there. The earliest qualifying completion may have no ready inventory and simply continue; quotas are never caught up. Inventory expires before 1 hour; failed loads back off. Only the SDK shown callback consumes caps. Reservation/rechecks handle double taps, consent changes, location changes, missing/stale safety and modal conflicts. A displayed SDK interstitial cannot be programmatically closed; existing warning state is surfaced as normal UI after dismissal.

## Privacy, editorial copy and reporting

UMP updates at launch, loads required forms, exposes required privacy choices, rechecks `canRequestAds`, deduplicates startup and suppresses requests on unresolved/disallowed consent. NPA is not a bypass. ATT is separate; no ATT prompt or tracking-permission assumption is added. Missing audience/privacy declarations block production. No mediation is installed. No verified purchase/entitlement source exists in this repository; a verified ad-free value can be injected and immediately suppresses ads. No purchases/subscriptions are invented.

Fifty original editorial lines live in `editorial_asides.v1.json`, including all 15 seed lines. Native selection has a 25% probability per eligible visit, capped at 2 per session; recent IDs are persisted. The section chooses once, not per callback/rebuild. Disable all with `DAYMAKER_AD_HUMOR=false`. Web adjacent humor is off. Severe/unknown/stale safety suppresses it. The immediate label always remains **Advertisements**. These are fictional DayMaker editorial asides, not real advertiser endorsements.

There is no analytics SDK in this app. `AdReporter` defaults to no-op and accepts an approved consent-aware implementation. Distinct events: opportunity, request, loaded, impression, paid, shown, failure, dismissal and suppression. Loaded is not an impression. Paid values preserve micros/currency/precision; amount = micros / 1,000,000. Aggregate by currency; never blindly sum them. Do not additionally log ad revenue if a future SDK already does so. No precise coordinates, captions, photos, document IDs or private content are sent to reporting or ad requests. Completion hashes remain local. Stable 10% assignment is implemented only when a host supplies measurement permission; it is not activated by assuming ad consent equals analytics consent.

Static dimensions do not guarantee still creatives. AdMob inventory controls (including content rating/category controls) may restrict inventory but do not provide a universal still-image switch. Do not freeze/screenshot/mask creatives or fake controls. Strict still sponsorship requires an actual image-only agreement and inventory.

## Documentation reviewed

- [Google Flutter quick start](https://developers.google.com/admob/flutter/quick-start)
- [Current UMP workflow](https://developers.google.com/admob/flutter/privacy)
- [Flutter banner dimensions/lifecycle](https://developers.google.com/admob/flutter/banner)
- [Interstitial callback and presentation lifecycle](https://developers.google.com/admob/flutter/interstitial)
- [Google Mobile Ads 9.1.0](https://pub.dev/packages/google_mobile_ads/versions/9.1.0), requiring Dart ≥3.10 and Flutter ≥3.38.1; installed Flutter 3.44.4 and Dart 3.12.2.
- [GPT controlled loading](https://developers.google.com/publisher-tag/guides/control-ad-loading)

See `PRODUCTION_CHECKLIST.md` for activation blockers and `VERIFICATION.md` for actual results. Passing tests does not imply account approval or live serving.
