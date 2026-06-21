# grumpy_skies

A new Flutter project.

## OpenWeather and Firebase setup

OpenWeather credentials must stay out of the Flutter app and this repository.
Store the provider key only as a Firebase/Google Secret Manager secret named
`OPENWEATHER_API_KEY`.

From the repo root, set the production secret with:

```sh
firebase functions:secrets:set OPENWEATHER_API_KEY
```

Paste the secret only into the Firebase CLI prompt. Do not save it in Dart,
Android, iOS, web, Remote Config, Firestore, docs, comments, screenshots, or
logs.

For local Functions emulator testing, Firebase can read secret values from
`functions/.secret.local`. Do not create that file with a real key unless you
intend to run the emulator locally, and never commit it.

The app defaults for live weather/radar rollout live in
`lib/config/weather_runtime_config.dart`. Backend URL selection lives in
`lib/config/weather_api_config.dart`.

The Flutter app calls only the app backend. It never sends the OpenWeather key
to Dart, Android, iOS, or web clients. Firebase Hosting rewrites `/api/**` to
the `api` function in `firebase.json`.

Default project and region:

```sh
FIREBASE_PROJECT_ID=wingman-interactive-live
FIREBASE_FUNCTIONS_REGION=us-central1
```

Default runtime behavior:

- Android/iOS/native default:
  `https://us-central1-wingman-interactive-live.cloudfunctions.net/api`
- Flutter web default: `/api`
- Manual override, all platforms:
  `--dart-define=WEATHER_API_BASE_URL=<full_api_base_url>`
- Local Functions emulator is used only when explicitly enabled:
  `--dart-define=USE_FUNCTIONS_EMULATOR=true`

Production/deployed backend Android test:

```sh
flutter run --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
```

Firebase Hosting rewrite backend test:

```sh
flutter run --dart-define=WEATHER_API_BASE_URL=https://wingman-interactive-live.web.app/api
```

Local Functions emulator for Android emulator:

```sh
firebase emulators:start --only functions --project wingman-interactive-live
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true --dart-define=FIREBASE_PROJECT_ID=wingman-interactive-live
```

In emulator mode, Android uses `http://10.0.2.2:5001/...`; iOS simulator and
local web use `http://127.0.0.1:5001/...`.

Physical Android device with a local emulator is not the default. Prefer the
deployed HTTPS backend. If local emulator testing is required:

```sh
adb reverse tcp:5001 tcp:5001
flutter run --dart-define=WEATHER_API_BASE_URL=http://127.0.0.1:5001/wingman-interactive-live/us-central1/api
```

Copy `.env.example` when configuring local environments. The example documents
`OPENWEATHER_API_KEY` and `OPENWEATHER_ENABLE_GLOBAL_FORECAST_RADAR`; do not
commit real values.

Deploy changed Functions or Hosting rewrites with:

```sh
firebase deploy --only functions --project wingman-interactive-live
firebase deploy --only functions,hosting --project wingman-interactive-live
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
