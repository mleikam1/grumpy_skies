import 'dart:typed_data';
import 'dart:ui';

import 'meme_export_types.dart';
import 'meme_export_io.dart' if (dart.library.js_interop) 'meme_export_web.dart'
    as platform;
export 'meme_export_types.dart';

class MemeExportService {
  MemeExportService({MemeExportAdapter? adapter})
      : adapter = adapter ?? platform.createMemeExportAdapter();
  final MemeExportAdapter adapter;

  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName) {
    _validatePng(bytes);
    return adapter.savePng(bytes, safeMemeFileName(fileName, 'png'));
  }

  /// Call directly from a new Share tap after rendering the export preview.
  /// There is no asynchronous encoding before the browser share invocation.
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
      {Rect? origin}) {
    _validatePng(bytes);
    return adapter.sharePng(bytes, safeMemeFileName(fileName, 'png'),
        origin: origin);
  }

  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
          {Rect? origin}) =>
      adapter.saveBackup(bytes, safeMemeFileName(fileName, 'daymaker'),
          origin: origin);

  void _validatePng(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24 ||
        bytes.length > 32 * 1024 * 1024 ||
        List.generate(8, (i) => bytes[i] != signature[i])
            .any((different) => different)) {
      throw const FormatException(
          'A complete PNG export is required. Please render again.');
    }
  }
}
