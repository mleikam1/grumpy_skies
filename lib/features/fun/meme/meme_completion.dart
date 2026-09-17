import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models/meme_document.dart';

/// A stable, opaque completion identity. Reopening, saving, or exporting the
/// same snapshot again does not manufacture another entertainment completion.
/// Neither document content nor photo references leave this hash boundary.
String memeCompletionRevision(MemeDocument document) {
  final content = document.toJson()
    ..remove('createdAt')
    ..remove('updatedAt');
  return sha256
      .convert(utf8.encode(jsonEncode(_canonical(content))))
      .toString();
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}
