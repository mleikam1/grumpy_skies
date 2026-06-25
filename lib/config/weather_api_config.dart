import 'package:flutter/foundation.dart';

class WeatherApiConfig {
  const WeatherApiConfig({
    required this.baseUrl,
    required this.useFunctionsEmulator,
    required this.firebaseProjectId,
    required this.functionsRegion,
    required this.platformLabel,
  });

  static const _baseUrlOverride = String.fromEnvironment(
    'WEATHER_API_BASE_URL',
  );
  static const _productionBaseUrlOverride = String.fromEnvironment(
    'WEATHER_PRODUCTION_API_BASE_URL',
  );
  static const _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
  );
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'grumpy-skies',
  );
  static const _functionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  final String baseUrl;
  final bool useFunctionsEmulator;
  final String firebaseProjectId;
  final String functionsRegion;
  final String platformLabel;

  static WeatherApiConfig get current => resolve();

  static WeatherApiConfig resolve({
    String? baseUrlOverride,
    String? productionBaseUrlOverride,
    bool? useFunctionsEmulator,
    String? firebaseProjectId,
    String? functionsRegion,
    bool? isWeb,
    TargetPlatform? platform,
  }) {
    final override = (baseUrlOverride ?? _baseUrlOverride).trim();
    final projectId = (firebaseProjectId ?? _firebaseProjectId).trim();
    final region = (functionsRegion ?? _functionsRegion).trim();
    final emulator = useFunctionsEmulator ?? _useFunctionsEmulator;
    final web = isWeb ?? kIsWeb;
    final resolvedPlatform = web ? null : platform ?? defaultTargetPlatform;
    final label = _platformLabel(web: web, platform: resolvedPlatform);
    final baseUrl = override.isNotEmpty
        ? override
        : _defaultBaseUrl(
            projectId: projectId,
            region: region,
            emulator: emulator,
            web: web,
            platform: resolvedPlatform,
            productionBaseUrlOverride:
                productionBaseUrlOverride ?? _productionBaseUrlOverride,
          );

    return WeatherApiConfig(
      baseUrl: _normalizeBaseUrl(baseUrl),
      useFunctionsEmulator: emulator,
      firebaseProjectId: projectId,
      functionsRegion: region,
      platformLabel: label,
    );
  }

  void debugLog() {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather API baseUrl=$baseUrl '
      'emulator=$useFunctionsEmulator platform=$platformLabel '
      'project=$firebaseProjectId region=$functionsRegion',
    );
  }

  static void debugLogOverride(String baseUrl) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather API baseUrl=${_normalizeBaseUrl(baseUrl)} '
      'emulator=false platform=override',
    );
  }

  static String _defaultBaseUrl({
    required String projectId,
    required String region,
    required bool emulator,
    required bool web,
    required TargetPlatform? platform,
    required String productionBaseUrlOverride,
  }) {
    if (emulator) {
      // Android emulator loopback points at the emulator itself. Use the
      // Android host alias so local Functions requests reach this computer.
      final host =
          !web && platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
      return 'http://$host:5001/$projectId/$region/api';
    }

    if (web) {
      return '/api';
    }

    final productionOverride = productionBaseUrlOverride.trim();
    if (productionOverride.isNotEmpty) {
      return productionOverride;
    }

    return 'https://$region-$projectId.cloudfunctions.net/api';
  }

  static String _platformLabel({
    required bool web,
    required TargetPlatform? platform,
  }) {
    if (web) return 'web';
    return switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
      null => 'unknown',
    };
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
