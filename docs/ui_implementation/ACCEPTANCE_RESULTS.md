# Acceptance results — October 9, 2026

Status: implementation and local functional verification complete; visual fidelity and live radar have the explicit limits below. This is not an exact or production-approved match.

## Verification ledger

| Check | Result | Evidence |
| --- | --- | --- |
| Original baseline | PASS: clean analyzer, 336 tests | logs/baseline-analyze.log, logs/baseline-test.log |
| Final formatting | PASS: 239 Dart files, zero changes required | logs/format-check.log |
| Final analyzer | PASS: no issues | logs/final-analyze.log |
| Final unit/widget suite | PASS: 426 tests | logs/final-tests.log |
| Fixture visual/responsive suite | PASS: 46 tests; final recaptures retained | logs/fixture-capture.log, VISUAL_QA.md |
| Web release | PASS; final artifact refresh also passed | logs/build-web.log, logs/build-results.json |
| Android debug APK | PASS; final artifact refresh also passed | logs/build-android.log, logs/build-results.json |
| iOS simulator debug | PASS, unsigned simulator app | logs/build-ios-simulator.log, logs/build-results.json |
| macOS build | BLOCKED: repository has no macOS desktop project | logs/build-macos.log |
| Diff whitespace | PASS | logs/diff-check.log |
| Live forecast service | HTTP 200, real forecast response | logs/live-service-check.json |
| Live global radar metadata | HTTP 200 with provider frame metadata | logs/live-service-check.json |
| Live global radar tiles | BLOCKED: health response upstream 401, no valid image | logs/live-service-check.json |

The first post-change full run had five failures: four old UI/catalog expectations and a new semantics-test teardown issue. These were corrected, preserving exact-roast, navigation, asset-manifest and rendered-PNG assertions. The final full run passed. A concurrent native-asset test invocation also hit a transient generated-file signing race; a subsequent clean run passed. Neither issue is presented as a pre-existing test failure.

## Behavior verified

- Separate Light/Dark tokens and persisted Light/Dark/System; new-install Light, legacy preference migration, serialized saves, errors/retry, saved-Dark first Flutter frame, System brightness and explicit override.
- Shared layout/artwork across appearances; no theme-driven weather request, persona reset, quote reroll, route replacement, scroll reset, draft change or document recolor. Tests include real Today state and real editor draft/undo with a keyboard inset.
- Four destinations in the approved order; /forecast retained; header Settings route/back, legacy redirects, focused editor/reveal navigation reservation and existing monetization guards.
- Today: real weather units/timezone/observation age, honest unavailable/offline states, race-safe location changes, real-data insight details, local Another, exact Share/Copy/meme snapshot.
- Roasts: real cached weather/local editorial pack, five preserved persona IDs/aliases, persisted selection, anti-repeat, genuine displayed session history and exact sharing. Reveal uses a frozen displayed snapshot or an empty state, with keyboard and reduced-motion support; invented rewards were removed.
- Fun: working local tabs, three quick templates plus featured editable meme, existing activities retained. All19 catalog templates render PNGs; all 15 legacy templates and saved asset paths remain available.
- Existing meme storage/import/recovery/autosave/layers/undo/export/cancel tests pass. Preview is memory-only; native lost-photo recovery stays enabled in production. New template/document query routes work.
- Serious alerts suppress roast display/actions; existing ad eligibility/consent/modal/operation tests pass. No ad was added to the hero or editor canvas.
- Widths 320/360/390/430/768/1440 exercised. Both themes at 2× text pass on all three main screens; reduced motion, keyboard Tab+Enter/Space, labelled/selected navigation semantics and editor keyboard inset pass. Settings/About/welcome also cover narrow large text. This is not a manual VoiceOver/TalkBack certification.

## Actual browser interaction

The in-app browser ran lib/main_preview.dart at 127.0.0.1:8765. Enabled Flutter semantics; opened Settings from Today, switched Dark, returned with the same quote/weather, navigated to Fun, opened Current mood in the real editor, typed “Same forecast. Tested in the real editor.”, and rendered a 1080×1080 PNG with that caption. Save Image reported “Download requested. Check your browser downloads.” The final filesystem download was not verified, so this is not claimed as completed file delivery. No native share sheet or photo-library save was manually tested.

A browser warning still identifies the pre-existing missing optional Crazy Day Predictor wheel PNG. Its existing Flutter fallback keeps the activity usable. It is outside the11 approved artwork assets and remains a legacy illustration task.

## Visual and asset limits

Six primary screenshots, important secondary/error/offline/editor/export screens, responsive captures, side-by-side comparisons, overlays and differences are retained. Final Today spacing fits all three fixture daily rows above navigation at 390×930 while preserving touch targets. The three-record fixture truthfully uses “3-day forecast”; rain wording does not invent a rising current probability. Detailed observations and comparison transforms are in VISUAL_QA.md.

All11 new illustrations are native-size reconstructions. They are not recovered originals. Character/scene proportions, font metrics, glows and gradients differ from the raster. Detached alpha pixels and bright fringes remain in some source artwork; attempted built-in image cleanup did not produce acceptable replacements. See ASSET_STATUS.md and artwork comparisons. This prevents an exact/production-ready visual claim.

## Platform and service limits

Android warns about future Kotlin migration. iOS warns about existing CocoaPods integration and missing App Store version/build metadata. No dependencies, bundle IDs, Firebase project, provider credentials or platform publishing configuration were changed. Windows/Linux builds were not run on this Mac. macOS cannot build until its target is added. Signed physical-device/release-store validation remains owner work.

The deployed weather forecast works, but global radar health reported an upstream authorization failure. This requires the owner to investigate provider entitlement/server credentials; this implementation does not change them. The fixture radar image exercises only a deliberately isolated unavailable state. No production deployment, public push, purchase or data wipe occurred.
