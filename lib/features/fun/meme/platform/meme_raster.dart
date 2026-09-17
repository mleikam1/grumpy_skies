import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

class MemeImportException implements Exception {
  const MemeImportException(this.message, {this.permissionDenied = false});
  final String message;
  final bool permissionDenied;
  @override
  String toString() => message;
}

class NormalizedMemeImage {
  const NormalizedMemeImage(this.png, this.width, this.height);
  final Uint8List png;
  final int width;
  final int height;
}

const memeMaxImportBytes = 20 * 1024 * 1024;
const memeMaxImportPixels = 40 * 1000 * 1000;
const memeMaxImageEdge = 2048;

bool isSafeRaster(Uint8List data) {
  if (data.length < 12) return false;
  final png = data[0] == 137 &&
      data[1] == 80 &&
      data[2] == 78 &&
      data[3] == 71 &&
      data[4] == 13 &&
      data[5] == 10 &&
      data[6] == 26 &&
      data[7] == 10;
  final jpeg = data[0] == 255 && data[1] == 216 && data[2] == 255;
  final webp = String.fromCharCodes(data.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(data.sublist(8, 12)) == 'WEBP';
  return png || jpeg || webp;
}

/// Checks encoded content before decode; dimensions are inspected without
/// allocating the full raster. The engine applies image orientation and the
/// new PNG retains pixels only, never source EXIF/GPS metadata.
Future<NormalizedMemeImage> normalizeMemeImage(Uint8List source) async {
  if (source.isEmpty || source.length > memeMaxImportBytes) {
    throw const MemeImportException('Choose a photo smaller than 20 MB.');
  }
  if (!isSafeRaster(source)) {
    throw const MemeImportException(
        'Choose a PNG, JPEG, or WebP photo. SVG and HTML cannot be imported.');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    final headerSize = memeRasterDimensions(source);
    if (headerSize.$1 <= 0 ||
        headerSize.$2 <= 0 ||
        headerSize.$1 * headerSize.$2 > memeMaxImportPixels) {
      throw const MemeImportException(
          'Choose a photo with no more than 40 million pixels.');
    }
    buffer = await ui.ImmutableBuffer.fromUint8List(source);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    // Flutter's encoded ImageDescriptor dimensions are unsupported on web.
    // Header parsing bounds allocation there before asking the engine to decode.
    final width = kIsWeb ? headerSize.$1 : descriptor.width;
    final height = kIsWeb ? headerSize.$2 : descriptor.height;
    if (width <= 0 || height <= 0 || width * height > memeMaxImportPixels) {
      throw const MemeImportException(
          'Choose a photo with no more than 40 million pixels.');
    }
    final scale = math.min(1.0, memeMaxImageEdge / math.max(width, height));
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (width * scale).round()),
      targetHeight: math.max(1, (height * scale).round()),
    );
    image = (await codec.getNextFrame()).image;
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) throw const FormatException('Could not encode photo.');
    return NormalizedMemeImage(
      encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes),
      image.width,
      image.height,
    );
  } on MemeImportException {
    rethrow;
  } catch (_) {
    throw const MemeImportException(
        'This photo could not be decoded. Try another PNG, JPEG, or WebP.');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Header-only dimensions for the accepted raster formats. Every read is
/// bounded, and encoded bytes are still fully decoded before persistence.
(int, int) memeRasterDimensions(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (!isSafeRaster(bytes)) throw const FormatException('Unsupported raster.');
  if (bytes[0] == 137) {
    if (bytes.length < 33 ||
        String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') {
      throw const FormatException('Missing PNG image header.');
    }
    return (data.getUint32(16), data.getUint32(20));
  }
  if (bytes[0] == 255) {
    var position = 2;
    var orientation = 1;
    while (position + 4 <= bytes.length) {
      if (bytes[position++] != 255) {
        throw const FormatException('Invalid JPEG segment.');
      }
      while (position < bytes.length && bytes[position] == 255) {
        position++;
      }
      if (position >= bytes.length) break;
      final marker = bytes[position++];
      if (marker == 0xd9 || marker == 0xda) break;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (position + 2 > bytes.length) break;
      final length = data.getUint16(position);
      if (length < 2 || position + length > bytes.length) {
        throw const FormatException('Invalid JPEG segment size.');
      }
      if (marker == 0xe1) {
        orientation = _jpegOrientation(bytes, position + 2, length - 2);
      }
      if ({
        0xc0,
        0xc1,
        0xc2,
        0xc3,
        0xc5,
        0xc6,
        0xc7,
        0xc9,
        0xca,
        0xcb,
        0xcd,
        0xce,
        0xcf
      }.contains(marker)) {
        if (length < 8) throw const FormatException('Invalid JPEG dimensions.');
        final height = data.getUint16(position + 3);
        final width = data.getUint16(position + 5);
        return orientation >= 5 && orientation <= 8
            ? (height, width)
            : (width, height);
      }
      position += length;
    }
    throw const FormatException('Missing JPEG dimensions.');
  }
  var position = 12;
  while (position + 8 <= bytes.length) {
    final chunk = String.fromCharCodes(bytes.sublist(position, position + 4));
    final size = data.getUint32(position + 4, Endian.little);
    final payload = position + 8;
    if (payload + size > bytes.length) {
      throw const FormatException('Invalid WebP chunk.');
    }
    int u24(int offset) =>
        bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
    if (chunk == 'VP8X' && size >= 10) {
      return (1 + u24(payload + 4), 1 + u24(payload + 7));
    }
    if (chunk == 'VP8 ' &&
        size >= 10 &&
        bytes[payload + 3] == 0x9d &&
        bytes[payload + 4] == 0x01 &&
        bytes[payload + 5] == 0x2a) {
      return (
        data.getUint16(payload + 6, Endian.little) & 0x3fff,
        data.getUint16(payload + 8, Endian.little) & 0x3fff
      );
    }
    if (chunk == 'VP8L' && size >= 5 && bytes[payload] == 0x2f) {
      final packed = data.getUint32(payload + 1, Endian.little);
      return (1 + (packed & 0x3fff), 1 + ((packed >> 14) & 0x3fff));
    }
    position = payload + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('Missing WebP dimensions.');
}

int _jpegOrientation(Uint8List bytes, int start, int length) {
  if (length < 14 ||
      String.fromCharCodes(bytes.sublist(start, start + 6)) !=
          'Exif\u0000\u0000') {
    return 1;
  }
  try {
    final tiff = ByteData.sublistView(bytes, start + 6, start + length);
    final endian = tiff.getUint16(0) == 0x4949 ? Endian.little : Endian.big;
    if (tiff.getUint16(2, endian) != 42) return 1;
    final ifd = tiff.getUint32(4, endian);
    final count = tiff.getUint16(ifd, endian);
    if (count > 512) return 1;
    for (var i = 0; i < count; i++) {
      final entry = ifd + 2 + i * 12;
      if (tiff.getUint16(entry, endian) == 0x112 &&
          tiff.getUint16(entry + 2, endian) == 3 &&
          tiff.getUint32(entry + 4, endian) == 1) {
        return tiff.getUint16(entry + 8, endian);
      }
    }
  } on RangeError {
    return 1;
  }
  return 1;
}
