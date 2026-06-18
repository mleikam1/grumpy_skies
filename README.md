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
`lib/config/weather_runtime_config.dart`. Production values can move to Firebase
Remote Config after the Firebase project is selected.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
