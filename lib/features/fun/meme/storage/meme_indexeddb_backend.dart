import 'dart:typed_data';
import 'package:idb_shim/idb.dart';
import 'meme_backend.dart';

/// Browser IndexedDB is origin-scoped and may be cleared or evicted. The UI
/// exposes portable backups; saved documents are never put in localStorage.
class IndexedDbMemeBackend implements MemeBackend {
  IndexedDbMemeBackend(this.factory, {this.databaseName = 'daymaker_memes_v1'});
  final IdbFactory factory;
  final String databaseName;
  Future<Database>? _database;

  Future<Database> _open() => _database ??= factory.open(
        databaseName,
        version: 1,
        onUpgradeNeeded: (event) {
          for (final name in ['documents', 'media', 'metadata']) {
            event.database.createObjectStore(name);
          }
        },
      );

  @override
  Future<Uint8List?> read(String collection, String key) async {
    validateStorageKey(key);
    final transaction =
        (await _open()).transaction(collection, idbModeReadOnly);
    final value = await transaction.objectStore(collection).getObject(key);
    await transaction.completed;
    return value == null
        ? null
        : Uint8List.fromList((value as List).cast<int>());
  }

  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    validateStorageKey(key);
    final transaction =
        (await _open()).transaction(collection, idbModeReadWrite);
    await transaction.objectStore(collection).put(bytes, key);
    await transaction.completed;
  }

  @override
  Future<void> remove(String collection, String key) async {
    validateStorageKey(key);
    final transaction =
        (await _open()).transaction(collection, idbModeReadWrite);
    await transaction.objectStore(collection).delete(key);
    await transaction.completed;
  }

  @override
  Future<List<String>> keys(String collection) async {
    final transaction =
        (await _open()).transaction(collection, idbModeReadOnly);
    final keys = await transaction.objectStore(collection).getAllKeys();
    await transaction.completed;
    return keys.cast<String>();
  }
}
