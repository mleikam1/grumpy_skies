import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'meme_backend.dart';

MemeBackend createMemeBackend() => FileMemeBackend();

/// Each completed write replaces one record atomically. A crash during the
/// temporary write leaves the preceding saved record intact.
class FileMemeBackend implements MemeBackend {
  FileMemeBackend({Directory? directory}) : _provided = directory;
  final Directory? _provided;
  Future<Directory>? _root;

  Future<Directory> _directory(String collection) async {
    validateStorageKey(collection);
    final root = await (_root ??= () async {
      final base = _provided ?? await getApplicationSupportDirectory();
      return Directory('${base.path}/daymaker_meme_studio')
          .create(recursive: true);
    }());
    return Directory('${root.path}/$collection').create(recursive: true);
  }

  Future<File> _file(String collection, String key) async {
    validateStorageKey(key);
    return File('${(await _directory(collection)).path}/$key.record');
  }

  @override
  Future<Uint8List?> read(String collection, String key) async {
    final file = await _file(collection, key);
    if (!await file.exists()) return null;
    final limit = collection == 'media' ? 20 * 1024 * 1024 : 8 * 1024 * 1024;
    if (await file.length() > limit) {
      throw const FormatException(
          'This local record exceeds the supported size. Its original file has been kept.');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    final file = await _file(collection, key);
    final temporary = File('${file.path}.pending');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> remove(String collection, String key) async {
    final file = await _file(collection, key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> keys(String collection) async {
    final directory = await _directory(collection);
    final result = <String>[];
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.endsWith('.record')) {
        final id = name.substring(0, name.length - 7);
        if (RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(id)) result.add(id);
      }
    }
    return result;
  }
}
