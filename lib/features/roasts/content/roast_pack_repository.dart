import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roast_pack_validator.dart';
import 'weather_roast_models.dart';

typedef RoastRemotePackFetcher = Future<String> Function(Uri url);

class RoastRemoteConfig {
  const RoastRemoteConfig({
    this.roastPackEnabled = false,
    this.roastPackVersion,
    this.roastPackUrl,
    this.roastPackSha256,
    this.roastPackMinAppBuild,
    this.roastDisabledIds = const {},
  });

  final bool roastPackEnabled;
  final String? roastPackVersion;
  final Uri? roastPackUrl;
  final String? roastPackSha256;
  final int? roastPackMinAppBuild;
  final Set<String> roastDisabledIds;

  static const disabled = RoastRemoteConfig();

  bool allowsCurrentBuild(int appBuildNumber) {
    final minBuild = roastPackMinAppBuild;
    return minBuild == null || appBuildNumber >= minBuild;
  }
}

abstract class RoastPackCache {
  Future<String?> readRemotePack();

  Future<void> writeRemotePack(String rawJson);

  Future<void> clearRemotePack();
}

class SharedPreferencesRoastPackCache implements RoastPackCache {
  SharedPreferencesRoastPackCache(this._prefs);

  static const _remotePackKey = 'roast_pack_remote_json_v1';

  final SharedPreferences _prefs;

  static Future<SharedPreferencesRoastPackCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesRoastPackCache(prefs);
  }

  @override
  Future<String?> readRemotePack() async {
    return _prefs.getString(_remotePackKey);
  }

  @override
  Future<void> writeRemotePack(String rawJson) async {
    await _prefs.setString(_remotePackKey, rawJson);
  }

  @override
  Future<void> clearRemotePack() async {
    await _prefs.remove(_remotePackKey);
  }
}

class InMemoryRoastPackCache implements RoastPackCache {
  String? _rawJson;

  @override
  Future<String?> readRemotePack() async => _rawJson;

  @override
  Future<void> writeRemotePack(String rawJson) async {
    _rawJson = rawJson;
  }

  @override
  Future<void> clearRemotePack() async {
    _rawJson = null;
  }
}

class RoastPackRepository {
  RoastPackRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/roasts/roast_pack_v1.json',
    RoastPackCache? cache,
    RoastRemotePackFetcher? remoteFetcher,
    RoastPackValidator validator = const RoastPackValidator(),
  })  : _assetBundle = assetBundle ?? rootBundle,
        _cache = cache,
        _remoteFetcher = remoteFetcher,
        _validator = validator;

  final AssetBundle _assetBundle;
  final String assetPath;
  final RoastPackCache? _cache;
  final RoastRemotePackFetcher? _remoteFetcher;
  final RoastPackValidator _validator;

  Future<RoastPack> loadBundledPack() async {
    final rawJson = await _assetBundle.loadString(assetPath);
    return _parseValidPack(rawJson);
  }

  Future<RoastPack> loadPack({
    RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
    int appBuildNumber = 1,
  }) async {
    final bundled = await loadBundledPack();
    if (!remoteConfig.roastPackEnabled ||
        !remoteConfig.allowsCurrentBuild(appBuildNumber)) {
      return bundled;
    }

    final cached = await _loadCachedRemotePack(remoteConfig);
    return cached ?? bundled;
  }

  Future<RoastPack> refreshRemotePack({
    required RoastRemoteConfig remoteConfig,
    int appBuildNumber = 1,
  }) async {
    if (!remoteConfig.roastPackEnabled ||
        !remoteConfig.allowsCurrentBuild(appBuildNumber)) {
      throw StateError('Remote roast pack is disabled for this build.');
    }

    final url = remoteConfig.roastPackUrl;
    final expectedSha = remoteConfig.roastPackSha256;
    final fetcher = _remoteFetcher;
    if (url == null || expectedSha == null || expectedSha.trim().isEmpty) {
      throw StateError('Remote roast pack URL and sha256 are required.');
    }
    if (fetcher == null) {
      throw StateError('No remote roast pack fetcher configured.');
    }

    final rawJson = await fetcher(url);
    _verifySha256(rawJson, expectedSha);
    final pack = _parseValidPack(rawJson);
    _verifyPackVersion(pack, remoteConfig);
    await _cache?.writeRemotePack(rawJson);
    return pack;
  }

  Future<RoastPack> loadWithRemoteFallback({
    required RoastRemoteConfig remoteConfig,
    int appBuildNumber = 1,
  }) async {
    final bundled = await loadBundledPack();
    final cached = await _loadCachedRemotePack(remoteConfig);
    try {
      return await refreshRemotePack(
        remoteConfig: remoteConfig,
        appBuildNumber: appBuildNumber,
      );
    } catch (_) {
      return cached ?? bundled;
    }
  }

  Future<RoastPack?> _loadCachedRemotePack(
    RoastRemoteConfig remoteConfig,
  ) async {
    final rawJson = await _cache?.readRemotePack();
    if (rawJson == null) return null;

    try {
      final expectedSha = remoteConfig.roastPackSha256;
      if (expectedSha != null && expectedSha.trim().isNotEmpty) {
        _verifySha256(rawJson, expectedSha);
      }
      final pack = _parseValidPack(rawJson);
      _verifyPackVersion(pack, remoteConfig);
      return pack;
    } catch (_) {
      await _cache?.clearRemotePack();
      return null;
    }
  }

  RoastPack _parseValidPack(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    final pack = RoastPack.fromJson(map);
    final result = _validator.validatePack(pack);
    if (!result.isValid) {
      throw FormatException(result.errors.join('\n'));
    }
    return pack;
  }

  void _verifyPackVersion(RoastPack pack, RoastRemoteConfig remoteConfig) {
    final expectedVersion = remoteConfig.roastPackVersion;
    if (expectedVersion != null &&
        expectedVersion.trim().isNotEmpty &&
        pack.packVersion != expectedVersion) {
      throw FormatException(
        'Remote pack version ${pack.packVersion} does not match '
        '$expectedVersion.',
      );
    }
  }

  void _verifySha256(String rawJson, String expectedSha) {
    final digest = sha256.convert(utf8.encode(rawJson)).toString();
    if (digest.toLowerCase() != expectedSha.trim().toLowerCase()) {
      throw const FormatException('Remote roast pack sha256 mismatch.');
    }
  }
}
