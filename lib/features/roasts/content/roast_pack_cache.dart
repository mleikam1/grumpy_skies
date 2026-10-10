import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fun/meme/storage/meme_backend.dart';
import '../../fun/meme/storage/meme_backend_io.dart'
    if (dart.library.js_interop) '../../fun/meme/storage/meme_backend_web.dart';

abstract class RoastPackCache {
  Future<String?> readRemotePack();
  Future<void> writeRemotePack(String rawJson);
  Future<void> clearRemotePack();
}

abstract class RoastShardCache implements RoastPackCache {
  Future<String?> readShard(String key, {int? appBuild});
  Future<void> writeShard(String key, String rawJson, {int minAppBuild = 1});
  Future<bool> rollbackShard(String key);
  Future<List<String>> shardKeys();
  Future<String?> readBundled(String assetKey);
  Future<void> writeBundled(String assetKey, String rawJson);
}

/// Reuses the application's atomic file / IndexedDB storage boundary. Large
/// JSON blobs never go in preferences. Only a small active/previous pointer is
/// replaced after a complete, content-addressed blob write. Roast records use
/// namespaced metadata keys; they never appear as saved meme projects.
class DurableRoastPackCache implements RoastShardCache {
  DurableRoastPackCache(this.backend);
  final MemeBackend backend;
  Future<void> _writes = Future<void>.value();
  static const _indexKey = 'roast_pack_index_v2';
  static const _blobPrefix = 'roast_blob_';
  Future<void>? _legacyMigration;

  static Future<DurableRoastPackCache> create() async {
    final cache = DurableRoastPackCache(createMemeBackend());
    // One-time migration; remove the preferences blob only after durable write.
    try {
      await cache._migrateLegacyBlobs();
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString('roast_pack_remote_json_v1');
      if (legacy != null) {
        await cache.writeRemotePack(legacy);
        await prefs.remove('roast_pack_remote_json_v1');
      }
    } catch (_) {
      // Private mode / eviction / unavailable storage still permits bundles.
    }
    return cache;
  }

  // Early builds shared the meme document collection. Move only verified
  // content-addressed roast blobs so the saved-project library stays isolated.
  Future<void> _migrateLegacyBlobs() => _legacyMigration ??= () async {
        for (final key in await backend.keys('documents')) {
          if (!RegExp(r'^roast_[a-f0-9]{64}$').hasMatch(key)) continue;
          final bytes = await backend.read('documents', key);
          final hash = key.substring(6);
          if (bytes == null || sha256.convert(bytes).toString() != hash) {
            continue;
          }
          await backend.write('metadata', '$_blobPrefix$hash', bytes);
          await backend.remove('documents', key);
        }
      }();

  Future<Map<String, dynamic>> _index() async {
    await _migrateLegacyBlobs();
    final raw = await backend.read('metadata', _indexKey);
    if (raw == null) return {};
    return (jsonDecode(utf8.decode(raw)) as Map).cast<String, dynamic>();
  }

  Future<String?> _blob(Object? hash) async {
    if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      return null;
    }
    final bytes = await backend.read('metadata', '$_blobPrefix$hash');
    if (bytes == null || sha256.convert(bytes).toString() != hash) return null;
    return utf8.decode(bytes);
  }

  @override
  Future<String?> readShard(String key, {int? appBuild}) async {
    final entry = (await _index())[key];
    if (entry is! Map) return null;
    final active =
        appBuild == null || appBuild >= (entry['activeMinBuild'] as int? ?? 1)
            ? await _blob(entry['active'])
            : null;
    return active ??
        (appBuild == null ||
                appBuild >= (entry['previousMinBuild'] as int? ?? 1)
            ? await _blob(entry['previous'])
            : null);
  }

  @override
  Future<void> writeShard(String key, String rawJson, {int minAppBuild = 1}) {
    final operation =
        _writes.then((_) => _writeShard(key, rawJson, minAppBuild));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _writeShard(String key, String rawJson, int minAppBuild) async {
    final bytes = Uint8List.fromList(utf8.encode(rawJson));
    final hash = sha256.convert(bytes).toString();
    final index = await _index();
    final old = index[key];
    if (old is Map && old['active'] == hash && await _blob(hash) != null) {
      return;
    }
    await backend.write('metadata', '$_blobPrefix$hash', bytes);
    index[key] = {
      'active': hash,
      'activeMinBuild': minAppBuild,
      if (old is Map && old['active'] is String) ...{
        'previous': old['active'],
        'previousMinBuild': old['activeMinBuild'] ?? 1,
      },
    };
    await backend.write('metadata', _indexKey,
        Uint8List.fromList(utf8.encode(jsonEncode(index))));
    // Keep exactly active and last-known-good per key; orphan cleanup is local.
    final keep = index.values.whereType<Map>().expand((v) => v.values).toSet();
    try {
      for (final blobKey in await backend.keys('metadata')) {
        if (blobKey.startsWith(_blobPrefix) &&
            !keep.contains(blobKey.substring(_blobPrefix.length))) {
          await backend.remove('metadata', blobKey);
        }
      }
    } catch (_) {/* A later write retries orphan cleanup. */}
  }

  @override
  Future<bool> rollbackShard(String key) {
    final operation = _writes.then((_) => _rollbackShard(key));
    _writes = operation.then<void>((_) {}).catchError((Object _) {});
    return operation;
  }

  Future<bool> _rollbackShard(String key) async {
    final index = await _index();
    final entry = index[key];
    if (entry is! Map || await _blob(entry['previous']) == null) return false;
    index[key] = {
      'active': entry['previous'],
      'previous': entry['active'],
      'activeMinBuild': entry['previousMinBuild'] ?? 1,
      'previousMinBuild': entry['activeMinBuild'] ?? 1
    };
    await backend.write('metadata', _indexKey,
        Uint8List.fromList(utf8.encode(jsonEncode(index))));
    return true;
  }

  @override
  Future<List<String>> shardKeys() async => (await _index())
      .keys
      .where((key) => !key.startsWith('bundle_'))
      .toList(growable: false);
  @override
  Future<String?> readRemotePack() => readShard('legacy');
  @override
  Future<void> writeRemotePack(String rawJson) => writeShard('legacy', rawJson);
  @override
  Future<void> clearRemotePack() {
    final operation = _writes.then((_) => _clearRemotePack());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _clearRemotePack() async {
    final index = await _index()
      ..remove('legacy');
    await backend.write('metadata', _indexKey,
        Uint8List.fromList(utf8.encode(jsonEncode(index))));
  }

  @override
  Future<String?> readBundled(String assetKey) => readShard('bundle_$assetKey');
  @override
  Future<void> writeBundled(String assetKey, String rawJson) =>
      writeShard('bundle_$assetKey', rawJson);
}

class InMemoryRoastPackCache extends DurableRoastPackCache {
  InMemoryRoastPackCache() : super(MemoryMemeBackend());
}
