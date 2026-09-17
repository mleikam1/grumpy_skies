import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';
import 'package:web/web.dart' as web;
import 'meme_export_types.dart';

MemeExportAdapter createMemeExportAdapter() => BrowserMemeExportAdapter();

class BrowserMemeExportAdapter implements MemeExportAdapter {
  web.File _file(Uint8List bytes, String name, String mime) =>
      web.File([bytes.toJS].toJS, name, web.FilePropertyBag(type: mime));

  Future<MemeTransferResult> _download(
      Uint8List bytes, String name, String mime) async {
    try {
      final url = web.URL.createObjectURL(_file(bytes, name, mime));
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = name;
      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
      return const MemeTransferResult(MemeTransferStatus.downloaded,
          'Download requested. Check your browser downloads.');
    } catch (_) {
      return const MemeTransferResult(MemeTransferStatus.failed,
          'The browser could not start the download. Allow downloads and retry.');
    }
  }

  @override
  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName) =>
      _download(bytes, fileName, 'image/png');
  @override
  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
          {Rect? origin}) =>
      _download(bytes, fileName, 'application/json');

  @override
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
      {Rect? origin}) async {
    final data = web.ShareData(
        files: [_file(bytes, fileName, 'image/png')].toJS, title: 'DayMaker');
    try {
      if (!web.window.navigator.canShare(data)) {
        return _download(bytes, fileName, 'image/png');
      }
    } catch (_) {
      return _download(bytes, fileName, 'image/png');
    }
    try {
      // No await occurs before share: a fresh user gesture remains active.
      await web.window.navigator.share(data).toDart;
      return const MemeTransferResult(
          MemeTransferStatus.shared, 'File handed to the selected app.');
    } catch (error) {
      if (error.toString().contains('AbortError')) {
        return const MemeTransferResult(
            MemeTransferStatus.cancelled, 'Share cancelled.');
      }
      return const MemeTransferResult(MemeTransferStatus.unavailable,
          'Browser sharing is unavailable. Choose Save Image to download the PNG.');
    }
  }
}
