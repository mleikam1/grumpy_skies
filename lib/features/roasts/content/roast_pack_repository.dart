import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'roast_pack_cache.dart';
import 'roast_pack_validator.dart';
import 'roast_update_sync.dart';
import 'weather_roast_models.dart';

export 'roast_pack_cache.dart';
export 'roast_update_sync.dart';

typedef RoastRemotePackFetcher = Future<String> Function(Uri url);

/// Legacy configuration DTO; this is not the Firebase Remote Config SDK.
class RoastRemoteConfig {
  const RoastRemoteConfig(
      {this.roastPackEnabled = false,
      this.roastPackVersion,
      this.roastPackUrl,
      this.roastPackSha256,
      this.roastPackMinAppBuild,
      this.roastDisabledIds = const {},
      this.allowedOrigins = const {}});
  final bool roastPackEnabled;
  final String? roastPackVersion;
  final Uri? roastPackUrl;
  final String? roastPackSha256;
  final int? roastPackMinAppBuild;
  final Set<String> roastDisabledIds;
  final Set<String> allowedOrigins;
  static const disabled = RoastRemoteConfig();
  bool allowsCurrentBuild(int build) => build >= (roastPackMinAppBuild ?? 1);
}

/// All render-time APIs are local. Optional network work has a separate,
/// persisted foreground scheduler. Each raw JSON hash is parsed once.
class RoastPackRepository {
  RoastPackRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/roasts/roast_pack_v1.json',
    this.bundledRevision = '2026.10.10.1',
    RoastPackCache? cache,
    RoastRemotePackFetcher? remoteFetcher,
    RoastPackValidator validator = const RoastPackValidator(),
    RoastUpdateScheduler? scheduler,
  })  : _assetBundle = assetBundle ?? rootBundle,
        _cache = cache,
        _remoteFetcher = remoteFetcher,
        _validator = validator,
        scheduler = scheduler ?? RoastUpdateScheduler();
  final AssetBundle _assetBundle;
  final String assetPath;
  final String bundledRevision;
  final RoastPackCache? _cache;
  final RoastRemotePackFetcher? _remoteFetcher;
  final RoastPackValidator _validator;
  final RoastUpdateScheduler scheduler;
  final Map<String, RoastPack> _parsed = {};
  Future<RoastPack>? _bundled;
  Set<String> _knownDisabledIds = {};
  final _installedPersonas = <String>{};
  String sourceForPersona(String persona, String locale) =>
      _installedPersonas.contains('${normalizeRoastPersonaId(persona)}|$locale')
          ? 'installed'
          : 'bundled';
  Set<String> get disabledIds => Set.unmodifiable(_knownDisabledIds);

  Future<RoastPack> loadBundledPack() => _bundled ??= _loadBundled();
  Future<RoastPack> _loadBundled() async {
    final store = _cache;
    if (kIsWeb && store is RoastShardCache) {
      try {
        final cached = await store.readBundled(bundledRevision);
        if (cached != null) return _parseValidPack(cached);
      } catch (_) {/* evicted/corrupt/private mode: load the bundled asset */}
    }
    final raw = await _assetBundle.loadString(assetPath);
    final pack = _parseValidPack(raw);
    if (kIsWeb && store is RoastShardCache) {
      try {
        await store.writeBundled(bundledRevision, raw);
      } catch (_) {/* optional cache */}
    }
    return pack;
  }

  Future<RoastPack> loadPack({
    RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
    int appBuildNumber = 1,
  }) =>
      _loadPack(remoteConfig: remoteConfig, appBuildNumber: appBuildNumber);

  Future<RoastPack> loadInstalledPack({int appBuildNumber = 1}) =>
      _loadPack(includeInstalledUpdates: true, appBuildNumber: appBuildNumber);

  Future<RoastPack> _loadPack(
      {RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
      int appBuildNumber = 1,
      bool includeInstalledUpdates = false}) async {
    final bundled = await loadBundledPack();
    _installedPersonas.clear();
    try {
      final metadata = await scheduler.metadata.read();
      _knownDisabledIds = {
        ..._knownDisabledIds,
        ...((metadata['disabled_ids'] as List?) ?? []).cast<String>()
      };
    } catch (_) {/* bundle remains available */}
    _knownDisabledIds = {
      ..._knownDisabledIds,
      ...remoteConfig.roastDisabledIds
    };
    if ((!remoteConfig.roastPackEnabled && !includeInstalledUpdates) ||
        !remoteConfig.allowsCurrentBuild(appBuildNumber)) {
      return _disable(bundled);
    }
    final legacy = await _loadCachedRemotePack();
    final RoastPack base;
    if (legacy == null) {
      base = bundled;
    } else {
      final installedGroups =
          legacy.roasts.map((line) => '${line.persona}|${line.locale}').toSet();
      final retained = bundled.roasts.where((line) =>
          !installedGroups.contains('${line.persona}|${line.locale}'));
      final data = legacy.toJson();
      // Old single-pack installations may cover fewer personas/locales. Their
      // presence cannot erase the first-launch bundle for everyone else.
      data['personas'] = {...bundled.personas, ...legacy.personas}.toList();
      data['roasts'] = [
        ...retained.map((line) => line.toJson()),
        ...(data['roasts'] as List)
      ];
      // Namespace retained rules so legacy rule versions cannot alter them.
      final retainedRules = {
        for (final rule in bundled.rules) rule.id: 'bundled/${rule.id}'
      };
      for (final row in (data['roasts'] as List).take(retained.length)) {
        if (row['rule_id'] != null) {
          row['rule_id'] = retainedRules[row['rule_id']];
        }
      }
      data['rules'] = [
        ...bundled.rules
            .map((rule) => {...rule.toJson(), 'id': retainedRules[rule.id]}),
        ...legacy.rules.map((rule) => rule.toJson())
      ];
      base = RoastPack.fromJson(data);
    }
    if (legacy != null) {
      _installedPersonas.addAll(
          legacy.roasts.map((line) => '${line.persona}|${line.locale}'));
    }
    final store = _cache;
    if (store is! RoastShardCache) return _disable(base);
    try {
      var data = base.toJson();
      final versions = <String>[base.packVersion];
      for (final key in await store.shardKeys()) {
        if (key == 'legacy') continue;
        final raw = await store.readShard(key, appBuild: appBuildNumber);
        if (raw == null) continue;
        RoastPack pack;
        try {
          pack = _parseValidPack(raw);
        } catch (_) {
          continue;
        }
        final shard = pack.toJson();
        // A persona update must not silently change the meaning of a shared
        // bundled rule still used by another persona. Namespace installed rules.
        final scopedRules = <String, String>{
          for (final rule in pack.rules) rule.id: '$key/${rule.id}'
        };
        for (final rule in (shard['rules'] as List? ?? const [])) {
          rule['id'] = scopedRules[rule['id']];
        }
        for (final row in shard['roasts'] as List) {
          if (row['rule_id'] != null) {
            row['rule_id'] = scopedRules[row['rule_id']];
          }
        }
        _installedPersonas.addAll(
            pack.roasts.map((line) => '${line.persona}|${line.locale}'));
        final replacements =
            pack.roasts.map((line) => '${line.persona}:${line.locale}').toSet();
        data['roasts'] = [
          ...(data['roasts'] as List).where((item) =>
              !replacements.contains('${item['persona']}:${item['locale']}')),
          ...shard['roasts'] as List,
        ];
        final rules = <String, Object?>{};
        for (final rule in [
          ...(data['rules'] as List? ?? []),
          ...(shard['rules'] as List? ?? [])
        ]) {
          rules[rule['id'] as String] = rule;
        }
        if (rules.isNotEmpty) data['rules'] = rules.values.toList();
        versions.add(pack.packVersion);
      }
      data['pack_version'] = versions.toSet().join('+');
      return _disable(RoastPack.fromJson(data));
    } catch (_) {
      return _disable(base);
    }
  }

  RoastPack _disable(RoastPack pack) {
    if (_knownDisabledIds.isEmpty) return pack;
    final json = pack.toJson();
    json['roasts'] = (json['roasts'] as List)
        .where((line) => !_knownDisabledIds.contains(line['id']))
        .toList();
    return RoastPack.fromJson(json);
  }

  Future<RoastSyncResult> syncIfDue(
          {RoastUpdatePolicy policy = RoastUpdatePolicy.disabled,
          Set<String> relevantPersonas = const {},
          String locale = 'en-US'}) =>
      scheduler
          .run(
              policy: policy,
              install: (manifest, download) async {
                _knownDisabledIds = {
                  ..._knownDisabledIds,
                  ...(manifest['disabled_ids'] as List).cast<String>()
                };
                final store = _cache;
                if (store is! RoastShardCache) {
                  throw StateError('Durable roast storage is required.');
                }
                var installed = 0;
                for (final item in manifest['packs'] as List) {
                  final entry = (item as Map).cast<String, dynamic>();
                  final persona = entry['persona'] as String;
                  if (!relevantPersonas.contains(persona) ||
                      entry['locale'] != locale) {
                    continue;
                  }
                  if ((entry['min_app_build'] as num? ?? 1) > policy.appBuild) {
                    continue;
                  }
                  final expectedSha = entry['sha256'] as String;
                  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSha)) {
                    throw const FormatException('Invalid pack hash.');
                  }
                  final key = '${persona}_$locale';
                  final existing = await store.readShard(key);
                  if (existing != null && _hash(existing) == expectedSha) {
                    continue;
                  }
                  final url = Uri.parse(entry['url'] as String);
                  policy.validateUrl(url);
                  // Immutable URL must carry its content hash; publisher cannot overwrite
                  // a version name and accidentally rely on a stale CDN object.
                  if (!url.path.contains(expectedSha)) {
                    throw const FormatException(
                        'Pack URL is not content-addressed.');
                  }
                  final declaredSize = entry['bytes'] as int;
                  if (declaredSize <= 0 ||
                      declaredSize > policy.maxDecodedBytes) {
                    throw const FormatException('Invalid decoded pack size.');
                  }
                  final raw = await download(url, policy.maxDecodedBytes);
                  if (utf8.encode(raw).length != declaredSize) {
                    throw const FormatException('Pack size mismatch.');
                  }
                  _verifySha256(raw, expectedSha);
                  final pack = _parseValidPack(raw);
                  if (pack.personas.length != 1 ||
                      pack.personas.single != persona ||
                      pack.packVersion != entry['version'] ||
                      pack.roasts.any((line) =>
                          line.persona != persona || line.locale != locale)) {
                    throw const FormatException('Pack identity mismatch.');
                  }
                  final entryBuild =
                      (entry['min_app_build'] as num? ?? 1).toInt();
                  final manifestBuild =
                      (manifest['min_app_build'] as num? ?? 1).toInt();
                  await store.writeShard(key, raw,
                      minAppBuild: entryBuild > manifestBuild
                          ? entryBuild
                          : manifestBuild); // Atomic pointer install after validation.
                  installed++;
                }
                return installed;
              })
          .then((result) async {
        // A download kill switch still carries recalls. Publish them to current
        // selectors even when installation was skipped or later failed.
        try {
          final state = await scheduler.metadata.read();
          _knownDisabledIds = {
            ..._knownDisabledIds,
            ...((state['disabled_ids'] as List?) ?? []).cast<String>()
          };
        } catch (_) {/* Preserve the last known recall set. */}
        return result;
      });

  Future<bool> rollback(
      {required String persona, String locale = 'en-US'}) async {
    final store = _cache;
    return store is RoastShardCache &&
        await store.rollbackShard('${persona}_$locale');
  }

  /// Legacy direct-download API intentionally fails closed. Call syncIfDue
  /// with a verified static manifest instead; rendering is always local.
  Future<RoastPack> refreshRemotePack(
      {required RoastRemoteConfig remoteConfig, int appBuildNumber = 1}) async {
    if (!remoteConfig.roastPackEnabled ||
        !remoteConfig.allowsCurrentBuild(appBuildNumber)) {
      throw StateError('Remote roast pack is disabled for this build.');
    }
    final url = remoteConfig.roastPackUrl;
    final sha = remoteConfig.roastPackSha256;
    if (url == null || sha == null || _remoteFetcher == null) {
      throw StateError('Remote roast pack URL, hash and fetcher are required.');
    }
    // Direct downloading bypassed scheduling in the old API. Refuse it: callers
    // must move to the explicit static-manifest foreground sync path.
    throw UnsupportedError('Use syncIfDue with a verified static manifest.');
  }

  Future<RoastPack> loadWithRemoteFallback(
          {required RoastRemoteConfig remoteConfig, int appBuildNumber = 1}) =>
      loadPack(remoteConfig: remoteConfig, appBuildNumber: appBuildNumber);

  Future<RoastPack?> _loadCachedRemotePack() async {
    try {
      final raw = await _cache?.readRemotePack();
      // Installed content is validated on its own merits. A newly advertised
      // version/hash must never invalidate this last-known-good content.
      return raw == null ? null : _parseValidPack(raw);
    } catch (_) {
      return null;
    }
  }

  RoastPack _parseValidPack(String raw) {
    final key = _hash(raw);
    if (_parsed.containsKey(key)) return _parsed[key]!;
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final result = _validator.validateJson(map);
    final pack = RoastPack.fromJson(map);
    if (!result.isValid) throw FormatException(result.errors.join('\n'));
    // Bound memory to the bundle and recently used persona shards.
    if (_parsed.length >= 16) _parsed.remove(_parsed.keys.first);
    return _parsed[key] = pack;
  }

  static String _hash(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();
  void _verifySha256(String raw, String expectedSha) {
    if (_hash(raw) != expectedSha.toLowerCase()) {
      throw const FormatException('Roast pack SHA-256 mismatch.');
    }
  }
}
