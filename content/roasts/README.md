# DayMaker Roast Content

The app does not call Google Sheets, AI, or Firestore to render roasts. Google
Sheets is only an optional admin editor for humans. The shipped app reads the
bundled JSON pack at `assets/roasts/roast_pack_v1.json`, then may use a cached
remote JSON pack later if Remote Config points at a valid Firebase Hosting file.

## Edit In Google Sheets

1. Open Google Sheets and create a blank sheet.
2. Choose **File > Import > Upload**.
3. Upload `content/roasts/roasts_template.csv`.
4. Choose **Replace spreadsheet** or **Insert new sheet**.
5. Keep the header row unchanged. Add or edit rows below it.
6. Export with **File > Download > Comma Separated Values (.csv)**.
7. Replace `content/roasts/roasts_template.csv` with the exported CSV.

## Build The Bundled Pack

Run this from the Flutter app root:

```sh
dart run tool/build_roast_pack.dart
```

The builder reads:

```text
content/roasts/roasts_template.csv
```

and writes:

```text
assets/roasts/roast_pack_v1.json
```

Validation fails on duplicate IDs, unknown personas, unknown roast types,
unknown roast levels, empty text, invalid placeholders, missing required
fields, and invalid numeric values. It warns on duplicate text, very long copy,
missing persona fallbacks, and inactive rows.

## Ship The Bundled Pack

`assets/roasts/roast_pack_v1.json` is registered in `pubspec.yaml`. Rebuild the
pack, run tests, and ship the app normally. The weather screen does not make an
extra weather API call for roasts; it builds `WeatherRoastContext` from the
already-loaded weather data.

## Optional Remote Pack

Remote Config should only act like a manifest. Do not put the whole roast
library in Remote Config. The optional keys are:

```text
roast_pack_enabled
roast_pack_version
roast_pack_url
roast_pack_sha256
roast_pack_min_app_build
roast_disabled_ids
```

Expected behavior:

- The bundled pack loads first.
- A cached remote pack can override the bundled pack only after schema
  validation and SHA-256 verification.
- A downloaded remote pack must also pass schema validation and SHA-256
  verification before it is cached.
- Any failure falls back to cached remote content or the bundled pack.
- The weather screen must not block waiting for a remote download.

Prepared Firebase Hosting files live in:

```text
public/content/roasts/manifest.json
public/content/roasts/roast_pack_v2026.06.26.1.json
```

If you deploy those files through Firebase Hosting, set Remote Config like this:

```text
roast_pack_enabled=true
roast_pack_version=2026.06.26.1
roast_pack_url=/content/roasts/roast_pack_v2026.06.26.1.json
roast_pack_sha256=b4079e3c71e696996abbf38fe7168e8a9d594c034c102c435bf5b9a8cf4f1dec
roast_pack_min_app_build=1
roast_disabled_ids=
```

## Add Content Types

Supported personas:

```text
karen
frat_bro
two_year_old
politician
grandpa
```

Supported roast types:

```text
today
hourly
commute
weekend
mood
```

Supported tags:

```text
clear
partly_cloudy
cloudy
light_rain
heavy_rain
storm
snow
fog
windy
hot
cold
humid
dry
bad_air
high_uv
nice
gross
commute_risk
weekend_good
fallback
severe
```

To add a persona, roast type, roast level, daypart, placeholder, or weather tag,
update `weather_roast_models.dart`, the CSV validator/builder tests, and the
CSV template. New severe-weather lines must stay safety-first.
