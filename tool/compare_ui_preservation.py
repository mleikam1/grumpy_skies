#!/usr/bin/env python3
"""Compare immutable fixture captures without third-party image dependencies.

PNG support is deliberately restricted to Flutter's noninterlaced 8-bit RGB/RGBA
output. It fails closed for other formats. Never writes/replaces reference files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/roasts/ui_evidence'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode_png(path):
    raw = path.read_bytes()
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not PNG: {path}')
    data = bytearray()
    offset = 8
    width = height = channels = None
    while offset < len(raw):
        length = struct.unpack('>I', raw[offset:offset + 4])[0]
        kind = raw[offset + 4:offset + 8]
        chunk = raw[offset + 8:offset + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunk)
            if depth != 8 or color not in (2, 6) or compression or filtering or interlace:
                raise ValueError(f'Unsupported PNG format: {path}')
            channels = 4 if color == 6 else 3
        elif kind == b'IDAT':
            data.extend(chunk)
        offset += 12 + length
    packed = zlib.decompress(data)
    stride = width * channels
    if len(packed) != (stride + 1) * height:
        raise ValueError(f'Unexpected decoded size: {path}')
    previous = bytearray(stride)
    pixels = bytearray()
    for y in range(height):
        start = y * (stride + 1)
        mode = packed[start]
        row = bytearray(packed[start + 1:start + 1 + stride])
        if mode not in range(5):
            raise ValueError(f'Unknown PNG filter: {mode}')
        for i in range(stride):
            a = row[i - channels] if i >= channels else 0
            b = previous[i]
            c = previous[i - channels] if i >= channels else 0
            if mode == 1:
                predictor = a
            elif mode == 2:
                predictor = b
            elif mode == 3:
                predictor = (a + b) // 2
            elif mode == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
            else:
                predictor = 0
            row[i] = (row[i] + predictor) & 255
        pixels.extend(row)
        previous = row
    return width, height, channels, pixels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', default='final', help='Final capture directory name; baseline is never modified.')
    phase = parser.parse_args().phase
    if phase == 'baseline' or '/' in phase or '\\' in phase or phase.startswith('.'):
        parser.error('Use a simple non-baseline capture directory name.')
    baseline = json.loads((EVIDENCE / 'baseline/manifest.json').read_text())
    result = {'baseline_integrity_errors': [], 'comparisons': [], 'protected_changes': []}
    for relative, expected in baseline['images'].items():
        before = ROOT / relative
        if not before.exists() or sha(before) != expected:
            result['baseline_integrity_errors'].append(relative)
            continue
        after = EVIDENCE / phase / before.name
        if not after.exists():
            result['comparisons'].append({'image': before.name, 'status': 'missing_final'})
            continue
        # Identical encoded bytes guarantee identical decoded pixels; avoid
        # needlessly expanding them. Different encodings still get a pixel test.
        if sha(after) == expected:
            width, height = struct.unpack('>II', before.read_bytes()[16:24])
            result['comparisons'].append({'image': before.name, 'status': 'identical', 'changed_pixels': 0, 'total_pixels': width * height})
            continue
        bw, bh, bc, bp = decode_png(before)
        aw, ah, ac, ap = decode_png(after)
        if (bw, bh, bc) != (aw, ah, ac):
            result['comparisons'].append({'image': before.name, 'status': 'size_or_format_changed'})
            continue
        changed = sum(bp[i:i + bc] != ap[i:i + ac] for i in range(0, len(bp), bc))
        result['comparisons'].append({'image': before.name, 'status': 'identical' if changed == 0 else 'different', 'changed_pixels': changed, 'total_pixels': bw * bh})
    protected = {}
    for name in ('ui_protected_baseline.json', 'ui_extended_protected_baseline.json', 'ui_display_contract_baseline.json'):
        protected.update(json.loads((ROOT / 'docs/roasts' / name).read_text())['sha256'])
    for relative, expected in sorted(protected.items()):
        path = ROOT / relative
        if not path.exists() or sha(path) != expected:
            result['protected_changes'].append(relative)
    result['identical_images'] = sum(v['status'] == 'identical' for v in result['comparisons'])
    result['baseline_image_count'] = len(baseline['images'])
    result['protected_file_count'] = len(protected)
    result['protected_note'] = 'All changes require human-readable data-wiring/dependency review; listed changes are not automatically approved.'
    output = EVIDENCE / ('comparison.json' if phase == 'final' else f'comparison_{phase}.json')
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'comparisons'}, indent=2))
    return int(bool(result['baseline_integrity_errors']) or result['identical_images'] != result['baseline_image_count'])


if __name__ == '__main__':
    sys.exit(main())
