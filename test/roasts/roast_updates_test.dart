import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_backend_io.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_indexeddb_backend.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_repository.dart';

class _LocalHttpOverrides extends HttpOverrides {}

class _HeaderRejectedClient extends http.BaseClient {
  bool cancelled = false;
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.AbortableRequest) {
      request.abortTrigger!.then((_) => aborted = true);
    }
    final controller = StreamController<List<int>>(onCancel: () {
      cancelled = true;
    });
    return http.StreamedResponse(controller.stream, 503,
        headers: {'content-type': 'application/json'});
  }
}

class _StalledBodyClient extends http.BaseClient {
  bool aborted = false;
  bool cancelled = false;
  int requests = 0;
  Stream<List<int>> _body(http.AbortableRequest request) async* {
    try {
      await request.abortTrigger;
      aborted = true;
    } finally {
      cancelled = true;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
          ++requests == 1
              ? _body(request as http.AbortableRequest)
              : Stream.value(utf8.encode('{}')),
          200,
          headers: {'content-type': 'application/json'});
}

class _Assets extends CachingAssetBundle {
  _Assets(this.raw);
  final String raw;
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    loads++;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(raw)));
  }
}

class _InterruptedBackend extends MemoryMemeBackend {
  bool failCommit = false;
  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    if (failCommit && collection == 'metadata') throw StateError('interrupted');
    return super.write(collection, key, bytes);
  }
}

String _bundle() => File('assets/roasts/roast_pack_v1.json').readAsStringSync();
String _shard(String version) {
  final data = jsonDecode(_bundle()) as Map<String, dynamic>;
  data['pack_version'] = version;
  data['personas'] = ['karen'];
  data['roasts'] =
      (data['roasts'] as List).where((r) => r['persona'] == 'karen').toList();
  return jsonEncode(data);
}

String _hash(String raw) => sha256.convert(utf8.encode(raw)).toString();
Map<String, dynamic> _manifest(String raw,
        {List<String> disabled = const []}) =>
    {
      'schema_version': 1,
      'min_app_build': 1,
      'disabled_ids': disabled,
      'packs': [
        {
          'persona': 'karen',
          'locale': 'en-US',
          'version': jsonDecode(raw)['pack_version'],
          'url': 'https://content.example/content/roasts/${_hash(raw)}.json',
          'sha256': _hash(raw),
          'bytes': utf8.encode(raw).length
        }
      ],
    };
RoastUpdatePolicy _policy({int budget = 1024 * 1024}) => RoastUpdatePolicy(
    enabled: true,
    manifestUrl: Uri.parse('https://content.example/manifest.json'),
    allowedOrigins: const {'https://content.example'},
    rollingBudgetBytes: budget);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default bundle loads once and 100 loads make no content requests',
      () async {
    var calls = 0;
    final assets = _Assets(_bundle());
    final repository = RoastPackRepository(
        assetBundle: assets,
        scheduler: RoastUpdateScheduler(
            metadata: MemoryRoastUpdateMetadataStore(),
            fetcher: (uri, a, b) async {
              calls++;
              throw StateError('network');
            }));
    for (var i = 0; i < 100; i++) {
      await repository.loadPack();
    }
    expect(assets.loads, 1);
    expect((await repository.syncIfDue()).status, RoastSyncStatus.disabled);
    expect(calls, 0);
  });

  test('new advertisement never invalidates working installed legacy content',
      () async {
    final cache = InMemoryRoastPackCache();
    await cache.writeRemotePack(_shard('installed-old'));
    final repository =
        RoastPackRepository(assetBundle: _Assets(_bundle()), cache: cache);
    final loaded = await repository.loadPack(
        remoteConfig: RoastRemoteConfig(
            roastPackEnabled: true,
            roastPackVersion: 'new-not-downloaded',
            roastPackSha256: '0' * 64));
    expect(loaded.packVersion, 'installed-old');
    expect(
        loaded.personas,
        containsAll(
            ['karen', 'frat_bro', 'grandpa', 'politician', 'two_year_old']));
    expect(loaded.roasts.any((line) => line.persona == 'grandpa'), isTrue);
    expect(await cache.readRemotePack(), isNotNull);
  });

  test('disabled IDs apply to bundles even while updates are disabled',
      () async {
    final id = jsonDecode(_bundle())['roasts'][0]['id'] as String;
    final metadata = MemoryRoastUpdateMetadataStore()
      ..state = {
        'disabled_ids': [id]
      };
    final repository = RoastPackRepository(
        assetBundle: _Assets(_bundle()),
        scheduler: RoastUpdateScheduler(metadata: metadata));
    expect(
        (await repository.loadPack()).roasts.any((r) => r.id == id), isFalse);
  });

  test(
      'weekly jitter persists, concurrent sync deduplicates, unchanged skips pack',
      () async {
    var now = DateTime.utc(2026, 10, 10);
    var manifestCalls = 0;
    var packCalls = 0;
    final raw = _shard('new-version');
    final metadata = MemoryRoastUpdateMetadataStore();
    final cache = InMemoryRoastPackCache();
    final scheduler = RoastUpdateScheduler(
        metadata: metadata,
        clock: () => now,
        jitter: () => const Duration(hours: 2),
        fetcher: (uri, a, b) async {
          final String body;
          if (uri.path.endsWith('manifest.json')) {
            manifestCalls++;
            body = jsonEncode(_manifest(raw));
          } else {
            packCalls++;
            body = raw;
          }
          return RoastDownload(Uint8List.fromList(utf8.encode(body)),
              utf8.encode(body).length + 1024);
        });
    final repository = RoastPackRepository(
        assetBundle: _Assets(_bundle()), cache: cache, scheduler: scheduler);
    Future<RoastSyncResult> sync() =>
        repository.syncIfDue(policy: _policy(), relevantPersonas: {'karen'});
    final results = await Future.wait([sync(), sync(), sync()]);
    expect(results.every((r) => r.status == RoastSyncStatus.updated), isTrue);
    expect(manifestCalls, 1);
    expect(packCalls, 1);
    now = now.add(const Duration(days: 7, hours: 1));
    expect((await sync()).status, RoastSyncStatus.throttled);
    now = now.add(const Duration(hours: 2));
    expect((await sync()).status, RoastSyncStatus.unchanged);
    expect(manifestCalls, 2);
    expect(packCalls, 1);
    expect((await repository.loadInstalledPack()).packVersion,
        contains('new-version'));
  });

  test(
      'restart failures use persisted backoff and reserve bytes conservatively',
      () async {
    var now = DateTime.utc(2026, 10, 10);
    var calls = 0;
    final metadata = MemoryRoastUpdateMetadataStore();
    RoastPackRepository repository() => RoastPackRepository(
        assetBundle: _Assets(_bundle()),
        cache: InMemoryRoastPackCache(),
        scheduler: RoastUpdateScheduler(
            metadata: metadata,
            clock: () => now,
            jitter: () => Duration.zero,
            fetcher: (uri, a, b) async {
              calls++;
              throw StateError('offline');
            }));
    expect((await repository().syncIfDue(policy: _policy())).status,
        RoastSyncStatus.failed);
    expect((metadata.state['ledger'] as List).single['bytes'], 4096 + 1024);
    expect((await repository().syncIfDue(policy: _policy())).status,
        RoastSyncStatus.throttled);
    now = now.add(const Duration(days: 7));
    expect((await repository().syncIfDue(policy: _policy())).status,
        RoastSyncStatus.failed);
    now = now.add(const Duration(days: 7));
    expect((await repository().syncIfDue(policy: _policy())).status,
        RoastSyncStatus.throttled);
    expect(calls, 2);
  });

  test('30-day budget prevents traffic then expires', () async {
    var now = DateTime.utc(2026, 10, 10);
    var calls = 0;
    final metadata = MemoryRoastUpdateMetadataStore()
      ..state = {
        'ledger': [
          {'at': now.toIso8601String(), 'bytes': 1024 * 1024 - 100}
        ]
      };
    final scheduler = RoastUpdateScheduler(
        metadata: metadata,
        clock: () => now,
        jitter: () => Duration.zero,
        fetcher: (uri, a, b) async {
          calls++;
          return RoastDownload(
              Uint8List.fromList(utf8
                  .encode('{"schema_version":1,"disabled_ids":[],"packs":[]}')),
              1100);
        });
    final repository = RoastPackRepository(
        assetBundle: _Assets(_bundle()),
        cache: InMemoryRoastPackCache(),
        scheduler: scheduler);
    expect((await repository.syncIfDue(policy: _policy())).status,
        RoastSyncStatus.budgetExhausted);
    expect(calls, 0);
    now = now.add(const Duration(days: 31));
    expect((await repository.syncIfDue(policy: _policy())).status,
        RoastSyncStatus.unchanged);
    expect(calls, 1);
  });

  test('download kill switch applies recalls to running selectors immediately',
      () async {
    final id = jsonDecode(_bundle())['roasts'][0]['id'] as String;
    var calls = 0;
    final metadata = MemoryRoastUpdateMetadataStore();
    final repository = RoastPackRepository(
        assetBundle: _Assets(_bundle()),
        cache: InMemoryRoastPackCache(),
        scheduler: RoastUpdateScheduler(
            metadata: metadata,
            fetcher: (uri, a, b) async {
              calls++;
              final raw = jsonEncode({
                'schema_version': 1,
                'disabled_ids': [id],
                'downloads_enabled': false,
                'packs': []
              });
              return RoastDownload(Uint8List.fromList(utf8.encode(raw)),
                  utf8.encode(raw).length + 1024);
            }));
    expect((await repository.syncIfDue(policy: _policy())).status,
        RoastSyncStatus.unchanged);
    expect(repository.disabledIds, contains(id));
    expect(calls, 1);
  });

  test('uncompressed content-length cannot undercount received body', () async {
    final downloader = RoastHttpDownloader(
        client: MockClient((_) async => http.Response('x' * 100, 200, headers: {
              'content-type': 'application/json',
              'content-length': '1'
            })));
    final result = await downloader.call(
        Uri.parse('https://content.example/p.json'), 200, 200);
    expect(result.accountedBytes, 1124);
    await expectLater(
        downloader.call(Uri.parse('https://content.example/p.json'), 50, 200),
        throwsFormatException);
  });

  test(
      'downgraded app reads compatible previous pack without deleting new pack',
      () async {
    final cache = InMemoryRoastPackCache();
    await cache.writeShard('karen', 'old', minAppBuild: 1);
    await cache.writeShard('karen', 'new', minAppBuild: 3);
    expect(await cache.readShard('karen', appBuild: 1), 'old');
    expect(await cache.readShard('karen', appBuild: 3), 'new');
  });

  for (final failure in [
    'hash',
    'size',
    'schema',
    'build',
    'unknownField',
    'origin',
    'http'
  ]) {
    test('$failure rejects update and retains installed content', () async {
      final old = _shard('old');
      var raw = _shard('new');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (failure == 'schema') {
        data['schema_version'] = 99;
        raw = jsonEncode(data);
      }
      if (failure == 'unknownField') {
        data['executable'] = 'no';
        raw = jsonEncode(data);
      }
      final manifest = _manifest(raw);
      final entry = (manifest['packs'] as List).single as Map;
      if (failure == 'size') entry['bytes'] = 999999999;
      if (failure == 'build') manifest['min_app_build'] = 999;
      if (failure == 'origin') {
        entry['url'] = 'https://evil.example/${_hash(raw)}.json';
      }
      if (failure == 'http') {
        entry['url'] = 'http://content.example/${_hash(raw)}.json';
      }
      final cache = InMemoryRoastPackCache();
      await cache.writeShard('karen_en-US', old);
      final scheduler = RoastUpdateScheduler(
          metadata: MemoryRoastUpdateMetadataStore(),
          jitter: () => Duration.zero,
          fetcher: (uri, a, b) async {
            final body = uri.path.endsWith('manifest.json')
                ? jsonEncode(manifest)
                : failure == 'hash'
                    ? '$raw '
                    : raw;
            return RoastDownload(Uint8List.fromList(utf8.encode(body)),
                utf8.encode(body).length + 1024);
          });
      final repository = RoastPackRepository(
          assetBundle: _Assets(_bundle()), cache: cache, scheduler: scheduler);
      expect(
          (await repository
                  .syncIfDue(policy: _policy(), relevantPersonas: {'karen'}))
              .status,
          RoastSyncStatus.failed);
      expect(await cache.readShard('karen_en-US'), old);
    });
  }

  test(
      'atomic pointer, corruption recovery, rollback, eviction, concurrent writes',
      () async {
    final backend = _InterruptedBackend();
    final cache = DurableRoastPackCache(backend);
    await cache.writeShard('a', 'old');
    backend.failCommit = true;
    await expectLater(cache.writeShard('a', 'partial'), throwsStateError);
    expect(await cache.readShard('a'), 'old');
    backend.failCommit = false;
    await Future.wait(
        [cache.writeShard('a', 'new'), cache.writeShard('b', 'other')]);
    expect(await cache.readShard('b'), 'other');
    expect(await cache.rollbackShard('a'), isTrue);
    expect(await cache.readShard('a'), 'old');
    await backend.write(
        'metadata', 'roast_blob_${_hash('old')}', Uint8List.fromList([1, 2]));
    expect(await cache.readShard('a'), 'new');
    backend.records.clear();
    expect(await cache.readShard('a'), isNull);
  });

  test(
      'roast cache remains isolated from saved meme projects and media cleanup',
      () async {
    final backend = MemoryMemeBackend();
    final store = MemeStore(backend);
    await backend.write('media', 'orphan', Uint8List.fromList([1]));
    await backend.write('metadata', 'library',
        Uint8List.fromList(utf8.encode('{"favorites":["kept"]}')));
    final cache = DurableRoastPackCache(backend);
    await cache.writeShard('karen', _shard('new'));
    await cache.writeBundled('starter', _bundle());
    expect(await store.listDocuments(), isEmpty);
    expect(store.recoveryIssues, isEmpty);
    await store.collectUnreferencedMedia({});
    expect(await backend.keys('media'), isEmpty);
    expect(await store.readMetadata(), {
      'favorites': ['kept']
    });
    expect(await cache.readShard('karen'), _shard('new'));
  });

  test('early roast document blobs migrate without touching meme records',
      () async {
    final backend = MemoryMemeBackend();
    final raw = _shard('old');
    final hash = _hash(raw);
    await backend.write(
        'documents', 'roast_$hash', Uint8List.fromList(utf8.encode(raw)));
    await backend.write(
        'metadata',
        'roast_pack_index_v2',
        Uint8List.fromList(utf8.encode(jsonEncode({
          'karen': {'active': hash, 'activeMinBuild': 1}
        }))));
    final cache = DurableRoastPackCache(backend);
    expect(await cache.readShard('karen'), raw);
    expect(await backend.keys('documents'), isEmpty);
    final store = MemeStore(backend);
    expect(await store.listDocuments(), isEmpty);
    expect(store.recoveryIssues, isEmpty);
  });

  test('native file cache persists across cache instances', () async {
    final directory = await Directory.systemTemp.createTemp('roast-test-');
    addTearDown(() => directory.delete(recursive: true));
    await DurableRoastPackCache(FileMemeBackend(directory: directory))
        .writeShard('karen', 'first');
    final restarted =
        DurableRoastPackCache(FileMemeBackend(directory: directory));
    expect(await restarted.readShard('karen'), 'first');
    await restarted.writeShard('karen', 'second');
    expect(await restarted.rollbackShard('karen'), isTrue);
    expect(await restarted.readShard('karen'), 'first');
  });

  test('IndexedDB adapter persists, retaining prior version for rollback',
      () async {
    final factory = newIdbFactoryMemory();
    final first = DurableRoastPackCache(
        IndexedDbMemeBackend(factory, databaseName: 'roast-test'));
    await first.writeShard('karen', 'first');
    final restarted = DurableRoastPackCache(
        IndexedDbMemeBackend(factory, databaseName: 'roast-test'));
    expect(await restarted.readShard('karen'), 'first');
    await restarted.writeShard('karen', 'second');
    expect(await restarted.rollbackShard('karen'), isTrue);
  });

  test('header rejection aborts request and cancels unconsumed response stream',
      () async {
    final client = _HeaderRejectedClient();
    await expectLater(
        RoastHttpDownloader(client: client)
            .call(Uri.parse('https://content.example/pack.json'), 100, 200),
        throwsFormatException);
    expect(client.cancelled, isTrue);
    expect(client.aborted, isTrue);
  });

  test(
      'body timeout aborts a pending async read before awaiting its cancellation',
      () async {
    final client = _StalledBodyClient();
    final downloader = RoastHttpDownloader(
        client: client, timeout: const Duration(milliseconds: 20));
    final uri = Uri.parse('https://content.example/pack.json');
    await expectLater(
        downloader.call(uri, 100, 200).timeout(const Duration(seconds: 1)),
        throwsA(isA<TimeoutException>()));
    expect(client.aborted, isTrue);
    expect(client.cancelled, isTrue);
    final next = await downloader.call(uri, 100, 200);
    expect(utf8.decode(next.bytes), '{}');
  });

  test('native HTTP stack decodes gzip exactly once and bounds decoded bytes',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = utf8.encode(jsonEncode({'content': 'rain ' * 1000}));
    final compressed = gzip.encode(payload);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.contentLength = compressed.length;
      request.response.add(compressed);
      await request.response.close();
    });
    // The only real traffic in this test is its local fixture server.
    final client = IOClient(_LocalHttpOverrides().createHttpClient(null));
    addTearDown(client.close);
    final downloader = RoastHttpDownloader(client: client);
    final uri = Uri.parse('http://127.0.0.1:${server.port}/test.json');
    final download =
        await downloader.call(uri, compressed.length + 16, payload.length + 16);
    expect(download.bytes, payload);
    expect(download.accountedBytes, greaterThanOrEqualTo(compressed.length));
    await expectLater(downloader.call(uri, compressed.length + 16, 100),
        throwsFormatException);
  });

  test('HTTP downloader rejects oversized decoded body, redirects and non-JSON',
      () async {
    for (final response in [
      http.Response('x' * 100, 200,
          headers: {'content-type': 'application/json'}),
      http.Response('', 302, headers: {'location': 'https://evil.example'}),
      http.Response('html', 200)
    ]) {
      final downloader =
          RoastHttpDownloader(client: MockClient((_) async => response));
      await expectLater(
          downloader.call(Uri.parse('https://content.example/p.json'), 50, 50),
          throwsFormatException);
    }
  });
}
