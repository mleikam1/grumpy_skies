import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_backend_io.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_indexeddb_backend.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:idb_shim/idb_client_memory.dart';

Future<Uint8List> photo() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xff448899), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(3, 2);
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return png;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native drafts and imported photos survive a repository restart',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('daymaker_store_test');
    addTearDown(() => directory.delete(recursive: true));
    final store = MemeStore(FileMemeBackend(directory: directory));
    final bytes = await photo();
    final media = await store.putMedia(bytes);
    final document = MemeDocument.blank(name: 'Personal photo')
        .copyWith(background: MemeBackground(assetRef: 'media:$media'));
    await store.save(document);
    // Simulate interruption before the atomic rename. The completed record
    // remains the only record used after restarting the repository.
    await File(
            '${directory.path}/daymaker_meme_studio/documents/${document.id}.record.pending')
        .writeAsString('{incomplete');
    await store.setFavorite('fog_buffering', true);
    final restarted = MemeStore(FileMemeBackend(directory: directory));
    final reopened = await restarted.load(document.id);
    expect(reopened!.background.assetRef, 'media:$media');
    expect(await restarted.getMedia(media), bytes);
    expect(await restarted.favorites(), {'fog_buffering'});
    expect(await restarted.missingMedia(reopened), isEmpty);
  });

  test(
      'IndexedDB schema stores binary assets and survives a connection restart',
      () async {
    final factory = newIdbFactoryMemory();
    final first = MemeStore(IndexedDbMemeBackend(factory));
    final bytes = await photo();
    final media = await first.putMedia(bytes);
    final document = MemeDocument.blank()
        .copyWith(background: MemeBackground(assetRef: 'media:$media'));
    await first.save(document);
    final reopened = MemeStore(IndexedDbMemeBackend(factory));
    expect((await reopened.listDocuments()).single.id, document.id);
    expect(await reopened.getMedia(media), bytes);
  });

  test(
      'corrupt records are isolated and retained without losing healthy drafts',
      () async {
    final backend = MemoryMemeBackend();
    final store = MemeStore(backend);
    final healthy = MemeDocument.blank();
    await store.save(healthy);
    await backend.write('documents', 'corrupt', Uint8List.fromList([1, 2, 3]));
    final recovered = await store.listDocuments();
    expect(recovered.single.id, healthy.id);
    expect(store.recoveryIssues, hasLength(1));
    expect(await backend.read('documents', 'corrupt'), isNotNull);
  });

  test('serialized writes and modification timestamps prevent stale save races',
      () async {
    final backend = _DelayedBackend();
    final store = MemeStore(backend);
    final old = MemeDocument.blank(name: 'Earlier');
    final newer = old.copyWith(
        name: 'Latest',
        updatedAt: old.updatedAt.add(const Duration(seconds: 1)));
    final first = store.save(old);
    final second = store.save(newer);
    backend.release.complete();
    await Future.wait([first, second]);
    await store.save(old);
    expect((await store.load(old.id))!.name, 'Latest');
    expect(backend.maxActiveWrites, 1);
  });

  test('quota failures remain recoverable and do not poison the write queue',
      () async {
    final backend = _QuotaBackend();
    final store = MemeStore(backend);
    final document = MemeDocument.blank();
    await expectLater(
        store.save(document),
        throwsA(isA<MemeStorageException>()
            .having((error) => error.quotaExceeded, 'quota exceeded', true)));
    backend.full = false;
    await store.save(document);
    expect((await store.listDocuments()).single.id, document.id);
  });

  test('backup embeds photos and imports a new editable document identity',
      () async {
    final originalStore = MemeStore(MemoryMemeBackend());
    final media = await originalStore.putMedia(await photo());
    final original = MemeDocument.blank()
        .copyWith(background: MemeBackground(assetRef: 'media:$media'));
    await originalStore.save(original);
    final backup = await originalStore.exportBackup(original);
    final destination = MemeStore(MemoryMemeBackend());
    final restored = await destination.importBackup(backup);
    expect(restored.id, isNot(original.id));
    expect(restored.layers.map((layer) => layer.text),
        original.layers.map((layer) => layer.text));
    expect(await destination.missingMedia(restored), isEmpty);
    expect((await destination.listDocuments()).single.id, restored.id);
  });

  test(
      'backup rejects traversal, missing media, unknown versions and executable content',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final document = MemeDocument.blank();
    Map<String, dynamic> backup(
            {Map<String, dynamic>? doc, Map<String, dynamic>? media}) =>
        {
          'format': 'daymaker-meme-project',
          'version': 1,
          'document': doc ?? document.toJson(),
          'media': media ?? {},
        };
    Future<void> reject(Map<String, dynamic> value) async => expectLater(
        store.importBackup(Uint8List.fromList(utf8.encode(jsonEncode(value)))),
        throwsA(anything));
    await reject(backup(doc: document.toJson()..['id'] = '../../outside'));
    await reject(backup()..['version'] = 999);
    final missing = document.copyWith(
        background: const MemeBackground(assetRef: 'media:missing'));
    await reject(backup(doc: missing.toJson()));
    await reject(backup(doc: missing.toJson(), media: {
      'missing': base64Encode(utf8.encode('<svg><script>bad()</script></svg>'))
    }));
    expect(await store.listDocuments(), isEmpty);
  });

  test('media collection respects saved documents and active undo history',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final media = await store.putMedia(await photo());
    final document = MemeDocument.blank()
        .copyWith(background: MemeBackground(assetRef: 'media:$media'));
    await store.save(document);
    await store.collectUnreferencedMedia({});
    expect(await store.getMedia(media), isNotNull);
    await store.delete(document.id);
    await store.collectUnreferencedMedia({media});
    expect(await store.getMedia(media), isNotNull);
    await store.collectUnreferencedMedia({});
    expect(await store.getMedia(media), isNull);
  });

  test(
      'backup remaps only asset references and preserves captions that resemble them',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final doc = MemeDocument.blank().copyWith(
        background: const MemeBackground(assetRef: 'media:old'),
        layers: [
          const MemeLayer(
              id: 'caption', type: MemeLayerType.text, text: 'media:old')
        ]);
    final backup = Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 'daymaker-meme-project',
      'version': 1,
      'document': doc.toJson(),
      'media': {'old': base64Encode(await photo())},
    })));
    final restored = await store.importBackup(backup);
    expect(restored.background.assetRef, isNot('media:old'));
    expect(restored.layers.single.text, 'media:old');
  });

  test('missing photos block save without deleting an earlier saved draft',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    final document = MemeDocument.blank();
    await store.save(document);
    await expectLater(
        store.save(document.copyWith(
            background: const MemeBackground(assetRef: 'media:gone'))),
        throwsA(isA<MemeStorageException>()));
    expect((await store.load(document.id))!.background.assetRef, isNull);
  });

  test(
      'small library metadata keeps caption pairs recent and export outcomes separate',
      () async {
    final store = MemeStore(MemoryMemeBackend());
    await store.rememberCaption('setup_punchline_1');
    await store.rememberCaption('setup_punchline_2');
    await store.rememberCaption('setup_punchline_1');
    expect(await store.recentCaptionIds(),
        ['setup_punchline_2', 'setup_punchline_1']);
    await store.recordExport(MemeExportRecord(
        documentId: 'project',
        fileName: 'meme.png',
        createdAt: DateTime.now(),
        width: 1080,
        height: 1920));
    expect((await store.readMetadata())['exports'], hasLength(1));
    expect(await store.listDocuments(), isEmpty);
  });
}

class _DelayedBackend extends MemoryMemeBackend {
  final release = Completer<void>();
  int activeWrites = 0;
  int maxActiveWrites = 0;
  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    activeWrites++;
    if (activeWrites > maxActiveWrites) maxActiveWrites = activeWrites;
    await release.future;
    await super.write(collection, key, bytes);
    activeWrites--;
  }
}

class _QuotaBackend extends MemoryMemeBackend {
  bool full = true;
  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    if (full) throw StateError('QuotaExceededError');
    return super.write(collection, key, bytes);
  }
}
