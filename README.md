# Grumpy Skies

A Flutter weather app backed by Firebase Functions and OpenWeather.

## OpenWeather and Firebase setup

OpenWeather credentials must stay out of the Flutter app and this repository.
The Flutter app calls only the Firebase Functions backend; it never sends the
OpenWeather key to Dart, Android, iOS, or web clients.

The production Firebase backend currently lives in the `wingman-interactive-live`
Firebase project. The `grumpy-skies` Firebase project ID is not currently
available to this Firebase account, so `https://us-central1-grumpy-skies.cloudfunctions.net/api`
returns Google HTML 404 pages instead of this app's JSON API.

The backend currently uses OpenWeather endpoints including:

- `/data/2.5/weather` for required current conditions
- `/data/4.0/onecall/timeline/1min`
- `/data/4.0/onecall/timeline/15min`
- `/data/4.0/onecall/timeline/1h`

The Forecast tab can show current weather with a standard OpenWeather key that
can access Current Weather API 2.5. Minute and timeline forecast enrichments
require One Call API 4.0 access. Radar tiles require the matching OpenWeather
Maps access. If those optional products are unavailable, the backend returns
safe JSON errors or transparent fallback radar tiles rather than HTML.

### Local OpenWeather key

Firebase Functions v2 secrets are read locally from `functions/.secret.local`.
That file is gitignored.

```sh
printf "OPENWEATHER_API_KEY=your_openweather_api_key_here\n" > functions/.secret.local
```

Optional non-secret Functions params can use
`functions/.env.wingman-interactive-live`:

```sh
printf "OPENWEATHER_ENABLE_GLOBAL_FORECAST_RADAR=false\n" > functions/.env.wingman-interactive-live
```

Safe placeholders are provided in `functions/.secret.local.example` and
`functions/.env.example`.

If `OPENWEATHER_API_KEY` is missing locally, the Functions backend returns a
clear JSON error with code `OPENWEATHER_API_KEY_MISSING` instead of exposing
any provider secret details.

### Backend URL selection

Backend URL selection lives in `lib/config/weather_api_config.dart`. Weather and
radar rollout flags live in `lib/config/weather_runtime_config.dart`.

Default Firebase project and region:

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

In emulator mode, Android uses `http://10.0.2.2:5001/wingman-interactive-live/us-central1/api`
because `127.0.0.1` points to the Android emulator itself. iOS simulator,
desktop, and local web use `http://127.0.0.1:5001/wingman-interactive-live/us-central1/api`.

### Local emulator

Start the Functions emulator from the repo root:

```sh
firebase emulators:start --only functions --project wingman-interactive-live
```

Verify the local endpoint from the host machine:

```sh
curl "http://127.0.0.1:5001/wingman-interactive-live/us-central1/api/weather/current?lat=38.8672283&lon=-94.6520357&units=imperial"
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
flutter run --dart-define=WEATHER_API_BASE_URL=http://<computer-lan-ip>:5001/wingman-interactive-live/us-central1/api
```

### Production

Run against the deployed Functions backend:

```sh
flutter run --dart-define=WEATHER_API_BASE_URL=https://us-central1-wingman-interactive-live.cloudfunctions.net/api
```

Set the deployed Firebase Functions secret only when you are ready to deploy:

```sh
firebase functions:secrets:set OPENWEATHER_API_KEY --project wingman-interactive-live
```

Deploy only after explicit approval:

```sh
firebase deploy --only functions:api --project wingman-interactive-live
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
