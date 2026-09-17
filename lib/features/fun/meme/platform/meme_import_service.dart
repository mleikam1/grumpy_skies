import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meme_document.dart';
import '../storage/meme_store.dart';
import 'meme_raster.dart';
export 'meme_raster.dart';

class ImportedMemePhoto {
  const ImportedMemePhoto(
      {required this.mediaId, required this.width, required this.height});
  final String mediaId;
  final int width;
  final int height;
  String get assetRef => 'media:$mediaId';
}

abstract interface class MemePhotoPicker {
  Future<XFile?> pick({required bool camera});
  Future<List<XFile>> recoverLost();
  bool get supportsCamera;
}

class SystemMemePhotoPicker implements MemePhotoPicker {
  SystemMemePhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  bool get supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  @override
  Future<XFile?> pick({required bool camera}) => _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        requestFullMetadata: false,
      );
  @override
  Future<List<XFile>> recoverLost() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
    final recovered = await _picker.retrieveLostData();
    if (recovered.exception != null) throw recovered.exception!;
    return recovered.files ?? [];
  }
}

class MemeImportService {
  MemeImportService(this.store, {MemePhotoPicker? picker})
      : picker = picker ?? SystemMemePhotoPicker();
  final MemeStore store;
  final MemePhotoPicker picker;
  bool get supportsCamera => picker.supportsCamera;

  Future<ImportedMemePhoto?> pick({bool camera = false}) async {
    if (camera && !supportsCamera) {
      throw const MemeImportException(
          'Camera capture is not available here. Use Upload Photo.');
    }
    try {
      final file = await picker.pick(camera: camera);
      return file == null ? null : await _persistFile(file);
    } on PlatformException catch (error) {
      throw _pickerError(error);
    }
  }

  Future<ImportedMemePhoto> _persistFile(XFile file) async {
    if (await file.length() > memeMaxImportBytes) {
      throw const MemeImportException('Choose a photo smaller than 20 MB.');
    }
    return importBytes(await file.readAsBytes());
  }

  Future<ImportedMemePhoto> importBytes(Uint8List bytes) async {
    final image = await normalizeMemeImage(bytes);
    final id = await store.putMedia(image.png);
    return ImportedMemePhoto(
        mediaId: id, width: image.width, height: image.height);
  }

  /// Invoke when the studio starts, including after Android activity recovery.
  /// Returned photos already live in durable storage, not picker caches.
  Future<List<ImportedMemePhoto>> recoverLostImages() async {
    try {
      final recovered = await picker.recoverLost();
      final result = <ImportedMemePhoto>[];
      for (final file in recovered) {
        result.add(await _persistFile(file));
      }
      return result;
    } on PlatformException catch (error) {
      throw _pickerError(error);
    }
  }

  Future<MemeDocument?> pickProjectBackup() async {
    final file = await files.openFile(acceptedTypeGroups: [
      const files.XTypeGroup(
        label: 'DayMaker project',
        extensions: ['json', 'daymaker'],
        mimeTypes: ['application/json'],
        // Custom .daymaker backups appear as generic data on iOS. The parser
        // validates their format and schema after selection.
        uniformTypeIdentifiers: ['public.json', 'public.data'],
      )
    ]);
    if (file == null) return null;
    if (await file.length() > MemeStore.maxBackupBytes) {
      throw const FormatException('Project backup exceeds 64 MB.');
    }
    return store.importBackup(await file.readAsBytes());
  }

  MemeImportException _pickerError(PlatformException error) {
    final denied = error.code.toLowerCase().contains('denied') ||
        error.code.toLowerCase().contains('restricted') ||
        error.code.toLowerCase().contains('access');
    return MemeImportException(
        denied
            ? 'Photo or camera access was declined. You can still use every bundled template.'
            : 'The photo picker could not open. Try Upload Photo again.',
        permissionDenied: denied);
  }
}
