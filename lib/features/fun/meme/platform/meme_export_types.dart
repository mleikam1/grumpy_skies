import 'dart:typed_data';
import 'dart:ui';

enum MemeTransferStatus {
  saved,
  downloaded,
  shared,
  cancelled,
  unavailable,
  denied,
  failed
}

class MemeTransferResult {
  const MemeTransferResult(this.status, this.message);
  final MemeTransferStatus status;
  final String message;
  bool get completed =>
      status == MemeTransferStatus.saved ||
      status == MemeTransferStatus.downloaded ||
      status == MemeTransferStatus.shared;
}

abstract interface class MemeExportAdapter {
  Future<MemeTransferResult> savePng(Uint8List bytes, String fileName);
  Future<MemeTransferResult> sharePng(Uint8List bytes, String fileName,
      {Rect? origin});
  Future<MemeTransferResult> saveBackup(Uint8List bytes, String fileName,
      {Rect? origin});
}

String safeMemeFileName(String input, String extension) {
  final stem = input
      .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final bounded = stem.length > 80 ? stem.substring(0, 80) : stem;
  return '${bounded.isEmpty ? 'daymaker_meme' : bounded}.$extension';
}
