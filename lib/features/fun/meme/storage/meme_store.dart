import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import '../models/meme_document.dart';
import '../platform/meme_raster.dart';
import 'meme_backend.dart';
import 'meme_backend_io.dart'
    if (dart.library.js_interop) 'meme_backend_web.dart' as platform;

export 'meme_backend.dart';

class MemeExportRecord {
  const MemeExportRecord(
      {required this.documentId,
      required this.fileName,
      required this.createdAt,
      required this.width,
      required this.height});
  final String documentId;
  final String fileName;
  final DateTime createdAt;
  final int width;
  final int height;
  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
        'width': width,
        'height': height
      };
}

class MemeStore {
  MemeStore(this.backend);
  factory MemeStore.platform() => MemeStore(platform.createMemeBackend());
  final MemeBackend backend;
  Future<void> _writes = Future<void>.value();
  final List<String> recoveryIssues = [];
  static const maxBackupBytes = 64 * 1024 * 1024;

  Future<T> _write<T>(Future<T> Function() action) {
    final result = _writes.then((_) async {
      try {
        return await action();
      } on FormatException {
        rethrow;
      } on MemeImportException {
        rethrow;
      } on MemeStorageException {
        rethrow;
      } catch (error) {
        throw storageFailure(error);
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> flush() => _writes;
  Uint8List _encode(Object json) =>
      Uint8List.fromList(utf8.encode(jsonEncode(json)));

  Future<List<MemeDocument>> listDocuments() async {
    await flush();
    recoveryIssues.clear();
    final documents = <MemeDocument>[];
    for (final key in await backend.keys('documents')) {
      try {
        final document = await load(key);
        if (document != null) documents.add(document);
      } catch (_) {
        recoveryIssues.add(
            'One saved project could not be read. Its original record has been kept for recovery.');
      }
    }
    documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return documents;
  }

  Future<MemeDocument?> load(String id) async {
    validateStorageKey(id);
    await flush();
    final bytes = await backend.read('documents', id);
    if (bytes == null) return null;
    final document = MemeDocument.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    if (document.id != id) {
      throw const FormatException('Project identity mismatch.');
    }
    return document;
  }

  Future<void> save(MemeDocument document) {
    // Capture immutable content before queuing: no mutable editor state enters
    // the queue, and an earlier edit cannot finish after a newer write.
    final bytes = _encode(MemeDocument.fromJson(document.toJson()).toJson());
    validateStorageKey(document.id);
    return _write(() async {
      for (final id in document.mediaIds) {
        if (await backend.read('media', id) == null) {
          throw const MemeStorageException(
              'A photo used by this project is missing. Re-import it before saving.');
        }
      }
      final previous = await backend.read('documents', document.id);
      if (previous != null) {
        try {
          final saved = MemeDocument.fromJson(
              jsonDecode(utf8.decode(previous)) as Map<String, dynamic>);
          if (saved.updatedAt.isAfter(document.updatedAt)) return;
        } on FormatException {/* Keep corrupt record until an explicit save. */}
      }
      await backend.write('documents', document.id, bytes);
    });
  }

  Future<void> delete(String id) =>
      _write(() => backend.remove('documents', id));

  Future<String> putMedia(Uint8List png) {
    if (png.length > memeMaxImportBytes || !isSafeRaster(png)) {
      throw const FormatException('Invalid or oversized media.');
    }
    final bytes = Uint8List.fromList(png);
    final id = sha256.convert(bytes).toString();
    return _write(() async {
      await backend.write('media', id, bytes);
      return id;
    });
  }

  Future<Uint8List?> getMedia(String id) async {
    validateStorageKey(id);
    await flush();
    return backend.read('media', id);
  }

  Future<Set<String>> missingMedia(MemeDocument document) async {
    final result = <String>{};
    for (final id in document.mediaIds) {
      if (await getMedia(id) == null) result.add(id);
    }
    return result;
  }

  /// Call only with all live history references. Saved projects are never
  /// evicted; an unreadable project conservatively prevents collection.
  Future<void> collectUnreferencedMedia(Set<String> activeHistoryMediaIds) =>
      _write(() async {
        final retained = {...activeHistoryMediaIds};
        for (final key in await backend.keys('documents')) {
          try {
            final bytes = await backend.read('documents', key);
            final document = MemeDocument.fromJson(
                jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>);
            retained.addAll(document.mediaIds);
          } catch (_) {
            return;
          }
        }
        for (final id in await backend.keys('media')) {
          if (!retained.contains(id)) await backend.remove('media', id);
        }
      });

  Future<Map<String, dynamic>> readMetadata() async {
    await flush();
    final bytes = await backend.read('metadata', 'library');
    if (bytes == null) return {};
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      recoveryIssues.add(
          'Favorites and recents could not be read. Saved projects are unaffected.');
      return {};
    }
  }

  Future<void> _updateMetadata(void Function(Map<String, dynamic>) update) =>
      _write(() async {
        final bytes = await backend.read('metadata', 'library');
        Map<String, dynamic> data = {};
        try {
          if (bytes != null) {
            data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          }
        } catch (_) {/* Projects and media are in separate records. */}
        update(data);
        await backend.write('metadata', 'library', _encode(data));
      });

  Future<Set<String>> favorites() async =>
      ((await readMetadata())['favorites'] as List? ?? [])
          .whereType<String>()
          .toSet();
  Future<void> setFavorite(String templateId, bool favorite) =>
      _updateMetadata((data) {
        final ids =
            (data['favorites'] as List? ?? []).whereType<String>().toSet();
        favorite ? ids.add(templateId) : ids.remove(templateId);
        data['favorites'] = ids.toList();
      });
  List<String> _captionHistory(Map<String, dynamic> data) {
    final ids =
        (data['recentCaptionIds'] as List? ?? []).whereType<String>().toList();
    // Migrate early studio records from newest-first to the suggestion deck's
    // oldest-first contract without touching documents or assets.
    return data['recentCaptionOrder'] == 'oldest_first'
        ? ids
        : ids.reversed.toList();
  }

  Future<List<String>> recentCaptionIds() async =>
      _captionHistory(await readMetadata());
  Future<void> rememberCaption(String id) => _updateMetadata((data) {
        final ids =
            _captionHistory(data).where((value) => value != id).toList();
        final history = [...ids, id];
        data['recentCaptionIds'] = history
            .skip(history.length > 80 ? history.length - 80 : 0)
            .toList();
        data['recentCaptionOrder'] = 'oldest_first';
      });
  Future<void> recordExport(MemeExportRecord record) => _updateMetadata((data) {
        data['exports'] = [record.toJson(), ...(data['exports'] as List? ?? [])]
            .take(50)
            .toList();
      });

  Future<Uint8List> exportBackup(MemeDocument document) async {
    final media = <String, String>{};
    var total = 0;
    for (final id in document.mediaIds) {
      final bytes = await getMedia(id);
      if (bytes == null) {
        throw const MemeStorageException(
            'A project photo is missing. Re-import it before making a backup.');
      }
      total += bytes.length;
      if (total > maxBackupBytes * 0.7) {
        throw const MemeStorageException(
            'This project is too large for a portable backup. Remove an unused photo and retry.');
      }
      media[id] = base64Encode(bytes);
    }
    final bytes = _encode({
      'format': 'daymaker-meme-project',
      'version': 1,
      'document': document.toJson(),
      'media': media
    });
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Project backup exceeds 64 MB.');
    }
    return bytes;
  }

  Future<MemeDocument> importBackup(Uint8List bytes) async {
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Project backup exceeds 64 MB.');
    }
    final root = jsonDecode(utf8.decode(bytes));
    if (root is! Map<String, dynamic> ||
        root['format'] != 'daymaker-meme-project' ||
        root['version'] != 1) {
      throw const FormatException(
          'This is not a supported DayMaker project backup.');
    }
    if (root['document'] is! Map<String, dynamic>) {
      throw const FormatException(
          'The backup is missing its editable project.');
    }
    final document =
        MemeDocument.fromJson(root['document'] as Map<String, dynamic>);
    final encodedMedia = root['media'];
    if (encodedMedia is! Map<String, dynamic> || encodedMedia.length > 100) {
      throw const FormatException('Invalid project media list.');
    }
    if (encodedMedia.keys.toSet().difference(document.mediaIds).isNotEmpty ||
        document.mediaIds.difference(encodedMedia.keys.toSet()).isNotEmpty) {
      throw const FormatException('Backup media does not match the project.');
    }
    final validated = <String, Uint8List>{};
    final remap = <String, String>{};
    var normalizedBytes = 0;
    // Validate every asset before any write, so a malformed backup cannot
    // partially replace a saved document or run uploaded SVG/HTML.
    for (final entry in encodedMedia.entries) {
      validateStorageKey(entry.key);
      if (entry.value is! String ||
          (entry.value as String).length > memeMaxImportBytes * 1.4) {
        throw const FormatException('Invalid project photo.');
      }
      final image =
          await normalizeMemeImage(base64Decode(entry.value as String));
      normalizedBytes += image.png.length;
      if (normalizedBytes > maxBackupBytes * .7) {
        throw const FormatException(
            'Decoded project photos exceed the supported backup size.');
      }
      final id = sha256.convert(image.png).toString();
      validated[id] = image.png;
      remap['media:${entry.key}'] = 'media:$id';
    }
    // Rewrite references only. Captions or names that happen to resemble a
    // media reference are user content and must remain byte-for-byte unchanged.
    final restoredJson = document.toJson();
    void replaceAssetRef(Map<String, dynamic> value) {
      final ref = value['assetRef'];
      if (ref is String && remap.containsKey(ref)) {
        value['assetRef'] = remap[ref];
      }
    }

    replaceAssetRef(restoredJson['background'] as Map<String, dynamic>);
    for (final layer in restoredJson['layers'] as List) {
      replaceAssetRef(layer as Map<String, dynamic>);
    }
    final now = DateTime.now();
    final name = document.name.length > 149
        ? document.name.substring(0, 149)
        : document.name;
    final restored = MemeDocument.fromJson(restoredJson).copyWith(
        id: newMemeId(),
        name: '$name (imported)',
        createdAt: now,
        updatedAt: now);
    for (final entry in validated.entries) {
      await putMedia(entry.value);
    }
    await save(restored);
    return restored;
  }
}
