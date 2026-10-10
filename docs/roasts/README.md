# Local roast catalog maintenance

Production keeps the approved DayMaker UI. The application-owned selector consumes installed JSON and existing weather state; CSV, editorial HTML and release tools are development-only. Optional static updates default to disabled. See [UI baseline](UI_BASELINE.md), [catalog coverage](CATALOG_REPORT.md) and [measured costs](COST_REPORT.md).

## Source and compatibility

Edit `content/roasts/roasts_template.csv` and the declarative `content/roasts/rules_v1.json`. No Google account or online sheet is required. Keep IDs stable. Reuse a family when the same premise recurs; 33 related lines currently share ten named families. Do not count city substitutions or punctuation variants as new jokes.

The original CSV columns remain supported. A CSV with `rule_id` or `family_id` opts into explicit mood, family, rule, status, review status and provenance. Canonical personas are `karen`, `frat_bro`, `grandpa`, `politician`, `two_year_old`; legacy aliases remain in the model. JSON schema remains compatible version 1, with a versioned rule registry. Dates are real ISO dates or UTC timestamps; `valid_until` is exclusive. Region fields require known context to match. There is no executable rule language.

Rules separate required-all facts, any-of groups, forbidden facts, scope, age, required placeholders and numeric constraints with units. The CSV's legacy numeric/code/daypart constraints remain hard constraints as well. Do not use rain probability as observed rain, freezing rain as heavy rain, or a whole-day maximum as current conditions. Condition codes and AQI have provider-specific meaning: [OpenWeather conditions](https://openweathermap.org/api/weather-conditions), [OpenWeather AQI](https://openweathermap.org/api/air-pollution).

Allowed placeholders are `city`, `temp`, `temp_unit`, `feels_like`, `condition`, `humidity`, `wind_mph`, `precip_chance`, `daypart`. `temp`/`feels_like` follow the selected temperature unit; `wind_mph` is explicitly mph. Require every referenced token in the rule. Unknown or missing required tokens reject a line; the selector never substitutes invented zeroes or blank factual values. `fallback_text` is retained for legacy compatibility, must be a complete literal, and does not bypass eligibility. End-of-pool fallback is application-owned or an eligible mild context-free line.

CSV notes/provenance/review status never enter public packs. Use `machine_reviewed` for automated work, `human_approved` only after actual human review, or `draft`. Only active rows with `active=TRUE` ship. Retired safety rows remain in source for audit; safety copy lives in application code. Cells beginning with `=`, `+`, `@`, or a non-numeric `-` require an apostrophe escape for spreadsheet safety; the builder removes that escape from displayed literal text.

## Build and review

Run from this repository root with the installed Flutter/Dart toolchain:

```sh
dart tool/build_roast_pack.dart
dart tool/validate_roast_pack.dart
flutter test test/roasts/roast_catalog_tooling_test.dart test/roasts/roast_pack_cli_test.dart test/roasts/roast_preview_test.dart
dart tool/build_roast_release.dart
python3 tool/test_stage_roast_release.py
python3 tool/measure_roast_costs.py
```

The CSV builder is pure Dart. The editorial preview intentionally runs through Flutter's test runner because it imports the production selector and current weather model graph; `dart tool/preview_roasts.dart` is not a supported command for this app. Preview output is `build/roast_preview/index.html`; serve the repository with `python3 -m http.server 8917 --bind 127.0.0.1`, then open `/build/roast_preview/index.html`. It has persona/type/context controls, candidate rule/mood filters, eligibility explanations and an inspect action using the actual same-persona expression assets. Candidate filters apply to the eligibility table; “Another” shows the production seeded sample. All context is synthetic, explicitly labeled, and no weather/AI service is contacted.

Review each batch separately for supported factual claims, voice, mood, readability, positivity, family grouping and repetition. The validator rejects duplicate IDs, punctuation-only duplicates, high token-overlap near duplicates, unknown schema/rules/fields, impossible fact combinations, invalid units/weights/dates, malformed tokens and missing mild unconditional fallbacks. Machine duplicate detection is a useful screen, not a human originality guarantee. New copy is currently at most 109 characters in this release.

Runtime JSON uses a fixed release epoch; wall-clock build time is in an audit sidecar. Sorted IDs and rules make bytes reproducible when input content/version is unchanged. Change `--pack-version` for an intentional release, and update `PackRoastRepository`'s bundled revision alongside a bundled content revision so persistent web caching cannot reuse old content under a new app build.

## Candidate release, publication and rollback

`build/roast_release` contains a candidate manifest, a release report, and immutable `packs/<sha256>.json` shards with gzip measurement sidecars. Hashes cover exact UTF-8 JSON bytes including their final newline, after HTTP decoding. `.gz` sidecars measure compression; they are not separate runtime URLs and must not be published with incorrect `Content-Encoding` headers. Older immutable files may remain in this local build folder between runs; the manifest identifies the active five.

No update origin or explicit roast Hosting target has been authorized and verified for this task. No publication occurred. The existing Firebase default is not sufficient evidence to enable optional downloads. Verify the intended existing static Hosting target, origin, deployed site baseline, cache headers, content type, HTTPS, CORS and native/browser compression behavior before enabling `RoastUpdatePolicy`. Preserve all existing site files, Firebase rewrites and unrelated headers.

Stage only into an isolated copy of the last deployed public directory. The following is a **template**, requiring operator-supplied verified paths and origin:

```sh
python3 tool/stage_roast_release.py --release build/roast_release --public "$ROAST_STAGED_PUBLIC" --origin "$ROAST_VERIFIED_ORIGIN"
```

The staging tool validates SHA-256, byte counts, persona/locale/version metadata and HTTPS URL shape, writes only `content/roasts`, refuses immutable-file replacement, and installs the manifest last. It cannot verify ownership/authorization of an origin. The intended deployed paths are `/content/roasts/packs/<sha256>.json` and `/content/roasts/manifest.json`. Use one-year immutable caching for hashes and a short manifest cache lifetime. Do not add cookies, signed URL churn, Functions or App Hosting for this public JSON.

After the staged tree is reviewed against the last deployed baseline and the existing target is explicitly authorized, use the existing deployment workflow restricted to that Hosting target, for example `firebase deploy --only "hosting:$ROAST_VERIFIED_TARGET" --project "$ROAST_VERIFIED_PROJECT" --config "$ROAST_REVIEWED_CONFIG"`. That config must point to the reviewed staged baseline; do not publish unrelated local app changes or an incomplete directory that erases the existing site. No values for these variables are inferred or configured by this task.

Archive the release folder and deployed manifest before publishing. Rollback re-stages an archived known-good release with the same command and `--release "$ROAST_KNOWN_GOOD_RELEASE"`; keep its hashed files available. Add `--disable-id ID` to disable bad IDs across bundled/updated content, or `--disable-downloads` for the manifest download kill switch. These are staged manifest changes, not immediate device commands. Offline clients cannot receive them until a later permitted sync. Local installed data remains usable when an advertised replacement fails.

The scheduler checks no more often than seven elapsed days on eligible foreground use, applies jitter/backoff and reserves conservative traffic before requests. It never runs from selection/persona switching. Defaults bound a manifest to 4 KiB, wire transfer to 256 KiB, decoded pack to 2 MiB and optional rolling 30-day traffic to 1 MiB per installation. These bounds are configurable, and the device allowance is not a global bill cap.
