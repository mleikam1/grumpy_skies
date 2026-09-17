import 'dart:typed_data';

/// A durable key/value boundary. Records and media never use preferences.
abstract interface class MemeBackend {
  Future<Uint8List?> read(String collection, String key);
  Future<void> write(String collection, String key, Uint8List bytes);
  Future<void> remove(String collection, String key);
  Future<List<String>> keys(String collection);
}

void validateStorageKey(String value) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(value)) {
    throw const FormatException('Invalid project or media identifier.');
  }
}

class MemeStorageException implements Exception {
  const MemeStorageException(this.message, {this.quotaExceeded = false});
  final String message;
  final bool quotaExceeded;
  @override
  String toString() => message;
}

MemeStorageException storageFailure(Object error) {
  final text = error.toString().toLowerCase();
  final quota = text.contains('quota') ||
      text.contains('no space') ||
      text.contains('disk full') ||
      text.contains('errno = 28');
  return MemeStorageException(
    quota
        ? 'Device storage is full. Free some space, then save again. You can also save a project backup.'
        : 'Your project could not be saved on this device. Please try again or save a project backup.',
    quotaExceeded: quota,
  );
}

/// Useful for deterministic tests and explicitly ephemeral previews only.
class MemoryMemeBackend implements MemeBackend {
  final Map<String, Map<String, Uint8List>> records = {};
  @override
  Future<Uint8List?> read(String collection, String key) async {
    final value = records[collection]?[key];
    return value == null ? null : Uint8List.fromList(value);
  }

  @override
  Future<void> write(String collection, String key, Uint8List bytes) async {
    validateStorageKey(key);
    (records[collection] ??= {})[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> remove(String collection, String key) async =>
      records[collection]?.remove(key);
  @override
  Future<List<String>> keys(String collection) async =>
      records[collection]?.keys.toList() ?? [];
}
