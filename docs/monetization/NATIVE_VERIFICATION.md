# Native SDK verification — 2026-09-17

The test builds use Google Mobile Ads Flutter 9.1.0, official Google demo app/unit IDs, real UMP, and the same `AdSection`, `MonetizationController`, native adapters, policy, and coordinator as the application. Production advertising remains disabled. These results do not establish AdMob account approval, paid demand, production serving, or age/privacy classification.

| Check | Android emulator-5556 | iPhone Air simulator (iOS 26.3) |
|---|---|---|
| UMP update and request permission | Resolved, `canRequestAds=true` | Resolved, `canRequestAds=true` |
| Privacy options required in observed locale | False | False |
| 320×50 banner | Real test creative, exact logical bounds, impression callback | Real test creative, exact logical bounds, impression callback |
| 300×250 MREC | Real test creative, exact logical bounds, impression callback | Real test creative, exact logical bounds, impression callback |
| Display lifecycle | Two requests total, one creative per view, no rebuild refresh, route teardown verified | Same |
| Interstitial preload | Loaded without presentation or consuming shown cap | Same |
| Interstitial explicit Done | SDK shown/impression callbacks; cap consumed once | SDK shown/impression callbacks; actual test creative visually inspected |
| Interstitial visual inspection | Android's first-use immersive-mode OS notice covered the creative | Test creative and Test mode indicator captured |
| SDK interstitial dismissal and navigation after dismissal | **Unverified**: native GUI unavailable | **Unverified**: native GUI unavailable; QA runner interrupted after captured presentation |

The desktop was locked, and the computer-use tool could not unlock it. Its native UI surface was unavailable, so the Android OS notice and native SDK Close controls could not be operated. No shell input injection, creative click, custom close control, forced SDK dismissal, or invented dismissal callback was used. Unit tests separately cover dismissal/failure/duplicate callback navigation; they do not replace this missing native dismissal check.

Full unmodified screenshots are in `screenshots/`:

- `android-forecast_banner_loaded.png`
- `android-meme_library_mrec_loaded.png`
- `ios-forecast_banner_loaded.png`
- `ios-meme_library_mrec_loaded.png`
- `android-interstitial_os_notice.png`
- `ios-interstitial_shown.png`

Display screenshots verify the immediate “Advertisements” label outside the creative, preserved SDK test labels, visible creative edges, and separation from the weather action and navigation. The screenshots use a clearly labeled QA weather fixture, not a production forecast screen or live weather response. No still-image-only creative claim is made.

The interstitial test uses a separate namespaced SharedPreferences store, persists three distinct fixture documents/revisions, restores a second session, and advances injected wall/monotonic clocks by the required engagement period. It never changes production limits or production policy history. A tester tap on the fixture Done button is the only presentation trigger.

Run the tests on an unlocked emulator/simulator:

```sh
flutter test integration_test/monetization_native_test.dart -d DEVICE_ID
flutter test integration_test/monetization_interstitial_native_test.dart -d DEVICE_ID
```

Close only the SDK's native Close control when it becomes available in the second test. A `dismissal_verified` log plus exactly one navigation and one post-dismissal safety notification completes that check. `DISMISSAL_UNVERIFIED` or an interrupted run must not be reported as dismissal success.

The app was absent on both selected devices before initial QA installation. No existing application data was cleared or uninstalled. EEA/UK consent-form choices, tracking permission changes, native no-fill with a real provider, actual physical devices, and production unit IDs were not exercised by these native runs.

## Existing Meme Studio flow

The final Android `meme_studio_flow_test.dart` passed on emulator-5556. It entered the actual Top caption control, saved and reopened a draft with the edited text, imported a personal-photo fixture and reopened its persisted media, rendered real square/portrait/story/two-panel PNGs with verified signatures and dimensions, exported and imported the project backup, and received the actual native “Image saved to Photos.” result. The optional integration-test screenshot channel was absent (`MissingPluginException`); only that capture step is reported unavailable. The product save and PNG assertions remain strict. A full host device screenshot from the earlier run independently records the saved state before that run failed at its screenshot step.

The untouched baseline Android `meme_studio_flow_test.dart` also passed on the same emulator, including its optional screenshot step. No baseline source changes were made. The cause of the screenshot-channel difference between the baseline and final build is not established; it must not be attributed to a product export failure or represented as a verified final screenshot-channel success.

The iOS run completed those earlier draft, photo, PNG, and backup assertions and reached the native add-to-Photos permission dialog. Its screenshot shows the OS Allow/Don't Allow choices. The locked desktop prevented operating that dialog, so the runner was stopped and **iOS Photos save remains unverified**. No permission was bypassed or granted through a shell command. Neither run exercised sharing to another application.

Evidence:

- `screenshots/android-meme_photos_saved.png` — final native successful-save result.
- `screenshots/ios-meme_photos_permission.png` — actual OS permission dialog.
- `native-meme-exports/android-native_*.png` — four actual Android-rendered exports.
- `native-meme-exports/android-native_photo.daymaker` — actual exported project backup used in the round-trip test.

The test uses a unique support-directory store, separate from normal user drafts. Run it with `flutter test integration_test/meme_studio_flow_test.dart -d DEVICE_ID`; iOS requires the native permission response when prompted. The app's normal draft/restart behavior is not replaced with a mock platform or storage adapter.
