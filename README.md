# Grumpy Skies

A Flutter weather app backed by Firebase Functions and OpenWeather.

## OpenWeather and Firebase setup

OpenWeather credentials must stay out of the Flutter app and this repository.
The Flutter app calls only the Firebase Functions backend; it never sends the
OpenWeather key to Dart, Android, iOS, or web clients.

The backend currently uses OpenWeather One Call API 4.0 endpoints, including:

- `/data/4.0/onecall/current`
- `/data/4.0/onecall/timeline/1min`
- `/data/4.0/onecall/timeline/15min`
- `/data/4.0/onecall/timeline/1h`

Your OpenWeather account/key must have One Call API 4.0 access enabled for live
current, minute, and timeline forecasts. Radar tiles also require the matching
OpenWeather Maps access for the configured key.

### Local OpenWeather key

Firebase Functions v2 secrets are read locally from `functions/.secret.local`.
That file is gitignored.

```sh
printf "OPENWEATHER_API_KEY=your_openweather_api_key_here\n" > functions/.secret.local
```

Optional non-secret Functions params can use `functions/.env.grumpy-skies`:

```sh
printf "OPENWEATHER_ENABLE_GLOBAL_FORECAST_RADAR=false\n" > functions/.env.grumpy-skies
```

Safe placeholders are provided in `functions/.secret.local.example` and
`functions/.env.example`.

If `OPENWEATHER_API_KEY` is missing locally, the Functions backend returns a
clear JSON error with code `openweather_secret_missing` instead of exposing any
provider secret details.

### Backend URL selection

Backend URL selection lives in `lib/config/weather_api_config.dart`. Weather and
radar rollout flags live in `lib/config/weather_runtime_config.dart`.

Default Firebase project and region:

```sh
FIREBASE_PROJECT_ID=grumpy-skies
FIREBASE_FUNCTIONS_REGION=us-central1
```

Default runtime behavior:

- Android/iOS/native default:
  `https://us-central1-grumpy-skies.cloudfunctions.net/api`
- Flutter web default: `/api`
- Manual override, all platforms:
  `--dart-define=WEATHER_API_BASE_URL=<full_api_base_url>`
- Local Functions emulator is used only when explicitly enabled:
  `--dart-define=USE_FUNCTIONS_EMULATOR=true`

In emulator mode, Android uses `http://10.0.2.2:5001/grumpy-skies/us-central1/api`
because `127.0.0.1` points to the Android emulator itself. iOS simulator,
desktop, and local web use `http://127.0.0.1:5001/grumpy-skies/us-central1/api`.

### Local emulator

Start the Functions emulator from the repo root:

```sh
firebase emulators:start --only functions --project grumpy-skies
```

Verify the local endpoint from the host machine:

```sh
curl "http://127.0.0.1:5001/grumpy-skies/us-central1/api/weather/current?lat=38.8672283&lon=-94.6520357&units=imperial"
```

Run the Flutter app on an Android emulator against local Functions:

```sh
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true
```

Run the Flutter app on iOS simulator or desktop against local Functions:

```sh
flutter run --dart-define=USE_FUNCTIONS_EMULATOR=true
```

For a physical Android device on the same network, `firebase.json` binds the
Functions emulator to `0.0.0.0:5001`. Use your computer's LAN IP and allow the
macOS firewall prompt if it appears:

```sh
ipconfig getifaddr en0
flutter run --dart-define=WEATHER_API_BASE_URL=http://<computer-lan-ip>:5001/grumpy-skies/us-central1/api
```

### Production

Run against the deployed Functions backend:

```sh
flutter run --dart-define=WEATHER_API_BASE_URL=https://us-central1-grumpy-skies.cloudfunctions.net/api
```

Set the deployed Firebase Functions secret only when you are ready to deploy:

```sh
firebase functions:secrets:set OPENWEATHER_API_KEY --project grumpy-skies
```

Deploy only after explicit approval:

```sh
firebase deploy --only functions --project grumpy-skies
firebase deploy --only functions,hosting --project grumpy-skies
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
