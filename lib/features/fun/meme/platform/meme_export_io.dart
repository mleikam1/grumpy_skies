import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'meme_export_types.dart';

MemeExportAdapter createMemeExportAdapter() => NativeMemeExportAdapter();

class NativeMemeExportAdapter implements MemeExportAdapter {
  NativeMemeExportAdapter(
      {bool? mobile, Future<ShareResult> Function(ShareParams)? shareSender})
      : _mobile = mobile ?? (Platform.isIOS || Platform.isAndroid),
        _shareSender = shareSender ?? SharePlus.instance.share;
  final bool _mobile;
  final Future<ShareResult> Function(ShareParams) _shareSender;
  @override
  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName) async {
    try {
      if (_mobile) {
        await Gal.putImageBytes(bytes,
            name: fileName.replaceFirst(RegExp(r'\.png$'), ''));
        return const MemeTransferResult(
            MemeTransferStatus.saved, 'Image saved to Photos.');
      }
      return await _saveFile(bytes, fileName, 'image/png');
    } on GalException catch (error) {
      if (error.type == GalExceptionType.accessDenied) {
        return const MemeTransferResult(MemeTransferStatus.denied,
            'Photos access was declined. Use Share to save the image to Files or another app.');
      }
      return const MemeTransferResult(MemeTransferStatus.failed,
          'The image could not be saved. Check available storage, or use Share.');
    } catch (_) {
      return const MemeTransferResult(MemeTransferStatus.failed,
          'The image could not be saved. Please retry or use Share.');
    }
  }

  Future<MemeTransferResult> _saveFile(
      Uint8List bytes, String name, String mime) async {
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) {
      return const MemeTransferResult(
          MemeTransferStatus.cancelled, 'Save cancelled.');
    }
    await XFile.fromData(bytes, name: name, mimeType: mime)
        .saveTo(location.path);
    return const MemeTransferResult(MemeTransferStatus.saved, 'File saved.');
  }

  @override
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
          {Rect? origin}) =>
      _share(bytes, fileName, 'image/png', origin);

  @override
  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
      {Rect? origin}) async {
    if (_mobile) {
      return _share(bytes, fileName, 'application/json', origin);
    }
    try {
      return await _saveFile(bytes, fileName, 'application/json');
    } catch (_) {
      return const MemeTransferResult(
          MemeTransferStatus.failed, 'Project backup could not be saved.');
    }
  }

  Future<MemeTransferResult> _share(
      Uint8List bytes, String fileName, String mime, Rect? origin) async {
    try {
      final file = await _prepareShareFile(bytes, fileName, mime);
      final result = await _shareSender(ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        title: 'DayMaker',
        sharePositionOrigin: origin ?? const Rect.fromLTWH(1, 1, 1, 1),
      ));
      return switch (result.status) {
        ShareResultStatus.success => const MemeTransferResult(
            MemeTransferStatus.shared, 'File handed to the selected app.'),
        ShareResultStatus.dismissed => const MemeTransferResult(
            MemeTransferStatus.cancelled, 'Share cancelled.'),
        ShareResultStatus.unavailable => const MemeTransferResult(
            MemeTransferStatus.unavailable,
            'Share sheet opened; this device cannot confirm the outcome.'),
      };
    } catch (_) {
      return const MemeTransferResult(MemeTransferStatus.failed,
          'Sharing is unavailable right now. Save the image and share it from Photos or Files.');
    }
  }

  Future<XFile> _prepareShareFile(
      Uint8List bytes, String name, String mime) async {
    final temp = await getTemporaryDirectory();
    final root = await Directory('${temp.path}/daymaker_meme_shares')
        .create(recursive: true);
    final directory = await root.createTemp('export_');
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    final old = <Directory>[];
    await for (final entry in root.list()) {
      if (entry is Directory && entry.path != directory.path) old.add(entry);
    }
    final dates = <String, DateTime>{};
    for (final entry in old) {
      dates[entry.path] = (await entry.stat()).modified;
    }
    old.sort((a, b) => dates[b.path]!.compareTo(dates[a.path]!));
    // Keep the newest twelve handoffs so another app can finish reading them.
    // Only our own expendable share copies are collected, never saved media.
    for (final entry in old.skip(11)) {
      try {
        await entry.delete(recursive: true);
      } catch (_) {/* Retry next share. */}
    }
    return XFile(file.path, name: name, mimeType: mime);
  }
}
