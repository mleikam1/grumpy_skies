#!/usr/bin/env python3
"""Read-only package checksum/PNG/JSON validation; Python standard library only.

Run after extraction: python tools/validate_package.py
This verifies the handoff, NOT the Flutter app or its visual fidelity.
"""
from __future__ import annotations
import hashlib
import json
import struct
import sys
from pathlib import Path


def safe_path(root: Path, name: str) -> Path:
    path=(root/name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f'Path leaves package: {name}')
    return path


def png_size(path: Path) -> tuple[int,int]:
    with path.open('rb') as handle:
        data=handle.read(24)
    if len(data)!=24 or data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Invalid PNG header: {path.name}')
    return struct.unpack('>II',data[16:24])


def main() -> int:
    root=Path(__file__).resolve().parents[1]
    errors=[]
    try:
        sums=json.loads((root/'CHECKSUMS.json').read_text(encoding='utf-8'))
        for name,expected in sums['files'].items():
            path=safe_path(root,name)
            if not path.is_file():
                errors.append(f'Missing: {name}'); continue
            actual=hashlib.sha256(path.read_bytes()).hexdigest()
            if actual!=expected: errors.append(f'Checksum mismatch: {name}')
        manifest=json.loads((root/'references/REFERENCE_MANIFEST.json').read_text(encoding='utf-8'))
        for item in manifest['source_images'].values():
            path=safe_path(root,item['path'])
            if png_size(path)!=(item['width'],item['height']): errors.append(f'Source size: {item["path"]}')
            if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']: errors.append(f'Source hash: {item["path"]}')
        ids=set()
        for item in manifest['crops']:
            if item['id'] in ids: errors.append(f'Duplicate crop ID: {item["id"]}')
            ids.add(item['id'])
            path=safe_path(root,item['file'])
            if png_size(path)!=(item['width'],item['height']): errors.append(f'Crop size: {item["file"]}')
            source=safe_path(root,item['source']); sw,sh=png_size(source)
            x0,y0,x1,y1=item['source_rect_xyxy']
            if not (0<=x0<x1<=sw and 0<=y0<y1<=sh): errors.append(f'Crop bounds: {item["file"]}')
            if (x1-x0,y1-y0)!=(item['width'],item['height']): errors.append(f'Crop metadata: {item["file"]}')
        for path in root.rglob('*.json'):
            json.loads(path.read_text(encoding='utf-8'))
        prohibited=[str(p.relative_to(root)) for p in root.rglob('*') if p.suffix.lower() in {'.ttf','.otf','.woff','.woff2'}]
        if prohibited: errors.append('Unexpected distributed font files: '+', '.join(prohibited))
    except (OSError,ValueError,KeyError,TypeError) as exc:
        errors.append(str(exc))
    if errors:
        print('\n'.join('FAIL: '+e for e in errors),file=sys.stderr);return 1
    print(f'PASS: {len(sums["files"])} file checksums; 2 source boards; {len(ids)} crop records; JSON and PNG metadata. '
          'This validates package integrity only, not application implementation.')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
