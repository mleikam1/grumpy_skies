# Production readiness — activation is not authorized

## Verified repository configuration

- Origin: `git@github.com:mleikam1/grumpy_skies.git`; base main `4f5632070a4ed785ba72cf72d29d0cb47fed982e`.
- Existing Firebase project: **wingman-interactive-live**, region **us-central1**. This is an existing shared backend; its name is not evidence of DayMaker ad inventory. The obsolete historical `grumpy-skies` project is not assumed. No project/hosting/billing/signing configuration was switched.
- Existing Android application ID: `com.example.grumpy_skies`; iOS bundle ID: `com.example.grumpySkies`. These remain unchanged. The publisher must establish intended store identifiers separately before production; no store app links were found or invented.
- AdMob account access: the available browser session opened AdMob signup rather than an authorized app/unit console. **No DayMaker production app/unit IDs, app-readiness status or approval have been verified.**
- Web publisher, approved domain, certified CMP and paid demand: **not configured/verified**. Mobile approval does not imply web approval; a GAM tag/account does not prove demand.
- Developer domain, store developer-website links, `app-ads.txt`, website `ads.txt`, seller IDs and existing seller records: **not verified**. No guessed records were deployed and shared hosting files were not overwritten.
- No analytics SDK, verified ad-free entitlement source, real subscriptions, or purchases exist in the inspected repository. Reporting is injected/no-op; verified entitlement support is an integration boundary, not a purchase claim.

## 1. Publisher and privacy decisions

1. Confirm the actual intended audience and applicable age handling. The 2-Year-Old fictional persona does not determine a child-directed classification. Do not assume all users are adults. Document child-directed/under-age consent decisions, supported markets and any necessary age flow before setting `DAYMAKER_AUDIENCE_DECLARED=true`; update SDK/UMP age tags consistently with those decisions. Missing declarations block activation. The current implementation leaves tags unspecified; no unverified adult classification is sent.
2. Finalize publisher legal identity/contact, complete privacy policy and retention/vendor disclosures, and exact Play Data Safety/App Store privacy labels based on the installed SDK versions and final enabled behavior. `web/privacy.html` and the app's Privacy information dialog truthfully describe the development implementation; neither is a completed store submission.
3. Configure and publish required UMP messages for each actual mobile app. Exercise required/optional privacy choices, revocation, returning users, offline failures and applicable regions. `canRequestAds` is authoritative; NPA is not a consent bypass. Verify required privacy options entry points. Keep ATT separate and test denied tracking without harming weather. No mediation should be enabled.
4. Only after verifying these choices may the publisher acknowledge `DAYMAKER_PRIVACY_READY=true`. Do not enable an audience-dependent SDK request configuration without completing step 1.

## 2. Create app-specific native inventory in the authorized AdMob account

Create/verify the two DayMaker apps using their confirmed store identifiers. Copy their **app IDs** (contain `~`) separately from **unit IDs** (contain `/`). Do not reuse IDs from Trivia Tussle, Wingman Browser or another app.

Create ten distinct ad units:

| Logical ID | Android | iOS | Console format/settings |
| --- | --- | --- | --- |
| forecast_banner | pending | pending | Banner; automatic refresh **Disabled**; request 320×50 / 728×90 |
| roasts_history_mrec | pending | pending | Banner; refresh **Disabled**; request 300×250 |
| fun_hub_mrec | pending | pending | Banner; refresh **Disabled**; request 300×250 |
| meme_library_mrec | pending | pending | Banner; refresh **Disabled**; request 300×250 |
| fun_complete_interstitial | pending | pending | Interstitial; no app-open/rewarded formats |

Verify content/category controls and test-device registration. The default maximum content rating is G; controls are not a guarantee of family-safe or motionless creatives. Do not invent an image-only SDK setting. Record console refresh settings, actual app-readiness status and unit mappings as review evidence. Then acknowledge `DAYMAKER_REFRESH_DISABLED=true` and `DAYMAKER_ADS_READY=true` only when verified.

## 3. Metadata, release guard and test mode

Development command, using official Google demo app/unit IDs only:

```sh
flutter run --dart-define=DAYMAKER_ADS_ENABLED=true --dart-define=DAYMAKER_TEST_ADS=true
```

The current native test-ad screenshots show dedicated SDK fixtures. They are not screenshots of advertising integrated into the full application screens.

The default build has ads disabled. Native manifest/plist include Google's official demo **app IDs** to keep SDK registration safe even when ads are disabled. Demo app metadata is allowed in an ads-disabled release, which does not initialize or request inventory.

Before an authorized ads-enabled production release:

- Android: supply the verified DayMaker app ID through Gradle property `daymakerAdMobAppId` (for example the build environment's `ORG_GRADLE_PROJECT_daymakerAdMobAppId`); it populates the manifest placeholder.
- iOS: replace the demo literal `GADApplicationIdentifier` in `ios/Runner/Info.plist` with the verified iOS DayMaker app ID. Preserve signing and bundle settings.
- Supply `DAYMAKER_ANDROID_AD_UNITS` and `DAYMAKER_IOS_AD_UNITS` as comma-separated unit IDs in the exact five-row order above. The ten production units must be distinct and valid.
- `tools/validate_monetization.py` runs automatically in Android preBuild and the iOS Flutter build phase. It rejects malformed/missing native metadata even when monetization is disabled; enabled release builds reject demo IDs, missing readiness flags and duplicate/missing unit mappings. Unit syntax is not account ownership evidence; manual app/unit ownership verification remains required.
- Production `DAYMAKER_TEST_ADS=true` is rejected by the native build guard and ignored by release runtime configuration. Do not ship integration-test entrypoints or intentionally simulated web providers.
- Leave `DAYMAKER_ADS_ENABLED=false` until explicit activation authorization. No production activation command was executed by this work.

Per-placement local switches use comma-separated logical IDs in `DAYMAKER_DISABLED_PLACEMENTS`. Set `DAYMAKER_AD_HUMOR=false` to disable all adjacent editorial copy. Tighten limits with `DAYMAKER_AD_ENGAGEMENT_SECONDS`, `DAYMAKER_AD_COMPLETIONS`, `DAYMAKER_AD_COOLDOWN_SECONDS`, `DAYMAKER_AD_SESSION_CAP`, and `DAYMAKER_AD_DAILY_CAP`. The policy clamps attempts to weaken the baseline of 180 seconds of engagement, 3 completed tasks, a 300-second cooldown, 1 ad per session, and 3 ads per rolling 24 hours. There is no live remote kill-switch endpoint; a release/configuration update is necessary to change local defaults.

## 4. Safety/backend readiness

The existing backend's successful bundled forecast adds explicit `alertCoverageVerified` / `alertsCheckedAt` only when the upstream response genuinely included alert coverage. Fallback/current-only responses remain unknown. This source change was **not deployed**. Until a verified backend supplies fresh coverage for the selected location, monetization fails closed. Unknown, stale, future, offline and active-warning state blocks interstitials and this conservative launch's display slots. Expiring observation times use the real clock. No ad callback fetches weather; new warning UI is retained and visible after dismissal.

Review and separately authorize the relevant existing-backend deployment when ready. Do not deploy unrelated functions or overwrite shared hosting/seller records. Test selected-location changes and warning updates on both sides of any native full-screen presentation.

## 5. Web provider activation is separately blocked

Manual GAM/GPT fixed-display adapter and real Flutter `HtmlElementView` lifecycle exist. `web/daymaker_ads.js` is a local bridge; it does not load Google's script until a visible eligible DOM slot and a connected, permitted CMP agree. It issues one `display`, no refresh timers, and destroys owned slots on retirement. No AdMob IDs, hidden frames, auto ads, web interstitials, fake clicks, H5 ads or modal AdSense banners are used. Adjacent web humor stays off.

Before enabling a website:

1. Verify ownership of the intended domain and provider account, site approval, actual demand, publisher policies and route/content eligibility. Do not assume this repository's shared Firebase project is an approved DayMaker website.
2. Connect a site-specific certified CMP implementation to `WebAdConsent`, including documented provider consent signals before permitting requests and a required privacy-options UI. The default `UnconfiguredWebAdConsent` cannot be enabled by a bool flag and makes no consent claim.
3. Review Flutter platform views with the real provider/renderer and production CSP, keyboard/modals, resizing, mobile/touch navigation, no fill, ad blocking and consent revocation. Simulated GPT harness checks are explicitly not live-provider approval.
4. Supply the four actual GAM display paths in `DAYMAKER_GPT_UNITS` in placement order. Only approved native fixed sizes are used. Set `DAYMAKER_WEB_APPROVED` and common readiness flags only after verification and explicit activation authorization.
5. Verify public About/Privacy/Help pages and crawlability, correct store/developer links, website `ads.txt` and mobile `app-ads.txt` on the **actual approved domains**. Preserve all existing authorized seller rows. Static pages here contain genuine information rather than hidden approval filler.
6. Web interstitials remain unavailable at launch. Web revenue must come from supported publisher reporting; no revenue is estimated client-side.

## 6. Measurement and launch decision

Inject a consent-aware reporter only into an approved analytics setup; do not add a per-event Firestore pipeline. Enable the stable 10% eligible local holdout only after measurement permission is established. Do not conflate UMP ad permission with analytics consent.

Evaluate by platform/cohort/date and preserve currency:

| Metric | Definition/evidence needed |
| --- | --- |
| Ad revenue/DAU | Verified paid revenue divided by same-day active eligible users |
| Impressions/session | Actual impression callbacks/reporting, not loads |
| Match rate | Matched/loaded requests divided by requests |
| Show rate | Actual shown interstitials divided by loaded opportunities, with suppression separately explained |
| Revenue/1,000 impressions | Revenue in one currency × 1,000 / actual impressions |
| D1/D7 retention | Consent-permitted stable cohort return rates; compare 10% holdout |
| Weather success | Usable successful forecast responses divided by attempts, with offline/stale distinct |
| p95 usable weather | First weather-visible latency, measured independently from consent/ads |
| Radar responsiveness | Frame/control response latency and error rate |
| Meme completion/export success | Delivered successful results/attempts; cancellations separate |

No revenue, retention or production latency lift is claimed from these tests. Finish the remaining device/consent/account checks in `VERIFICATION.md`, compare holdout weather/meme outcomes, and obtain explicit production activation/store publication authorization. Passing builds is not ad approval.
