# Baseline — 2026-10-09

Owner confirmed the September 17 checkout for this implementation.

- Repository: mleikam1/grumpy_skies; existing local checkout, not a prototype.
- Original branch: feat/weather-first-ad-monetization.
- Original HEAD: bedddc8 (Record baseline, native SDK, browser and build verification).
- Original working tree: clean. No user changes reset, deleted or stashed.
- Implementation branch: feat/approved-daymaker-light-dark, branched from local HEAD.
- Handoff copied without overwriting into docs/daymaker_exact_ui.
- AGENTS.md and four required DayMaker design documents read. New approved light layout and canonical characters override older visual proposals.
- Flutter 3.44.4 stable, Dart 3.12.2. Existing pubspec and lockfile retained; no dependency upgrade.
- Entrypoint: lib/main.dart; Provider/settings loaded before runApp; stable GoRouter; real OpenWeather/backend/cache/location repository in production.
- Verified defect: light, lightOnDark and dark theme getters all returned the same dark ThemeData; MaterialApp supplied only theme.
- Baseline flutter analyze: PASS, no issues (5.2s), log in logs/baseline-analyze.log.
- Baseline flutter test: PASS, 336 tests (26s); log in logs/baseline-test.log.
- Available local targets: Android emulator (API36), iOS simulator (26.3), macOS, web. Physical devices were not used.
- Baseline Today/Roasts/Fun captures were rendered from an isolated archive of bedddc8 and retained in screenshots/baseline/.

No live weather credential validation, device install, production deployment or public push is implied by this baseline.
