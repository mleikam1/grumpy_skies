#!/usr/bin/env python3
"""Validate and stage content-only publish/rollback files. Never deploys.

Use --release with a previously archived release for rollback. The destination
must be an isolated copy of the intended site's last deployed public directory.
Only content/roasts is written; existing immutable files are never overwritten.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlparse


def stage(release, public, origin, disable=(), downloads_enabled=True):
    parsed = urlparse(origin)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
            or parsed.password or parsed.path not in ('', '/')
            or parsed.query or parsed.fragment):
        raise ValueError('Provide an HTTPS origin, without path or credentials.')
    release, public = Path(release).resolve(), Path(public).resolve()
    manifest_path = release / 'manifest.json'
    if not manifest_path.exists():
        manifest_path = release / 'manifest.candidate.json'
    manifest = json.loads(manifest_path.read_text())
    if manifest.get('schema_version') != 1 or not isinstance(manifest.get('packs'), list):
        raise ValueError('Unsupported manifest schema.')
    copies = []
    for entry in manifest['packs']:
        digest = entry['sha256']
        if not re.fullmatch('[a-f0-9]{64}', digest):
            raise ValueError('Invalid SHA-256 filename.')
        source = release / 'packs' / f'{digest}.json'
        data = source.read_bytes()
        if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f'Corrupt release shard: {digest}')
        document = json.loads(data)
        if (document.get('schema_version') != 1
                or document.get('pack_version') != entry['version']
                or any(row['persona'] != entry['persona'] or row['locale'] != entry['locale']
                       for row in document['roasts'])):
            raise ValueError(f'Mismatched shard metadata: {digest}')
        path = f'content/roasts/packs/{digest}.json'
        entry['url'] = origin.rstrip('/') + '/' + path
        target = public / path
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f'Refusing to overwrite immutable shard: {target}')
        copies.append((target, data))
    ids = set(manifest.get('disabled_ids', [])) | set(disable)
    if any(not re.fullmatch('[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}', x) for x in ids):
        raise ValueError('Invalid disabled roast ID.')
    manifest['disabled_ids'] = sorted(ids)
    manifest['downloads_enabled'] = downloads_enabled
    manifest_bytes = (json.dumps(manifest, separators=(',', ':')) + '\n').encode()
    if len(manifest_bytes) > 4096:
        raise ValueError('Manifest exceeds runtime 4 KiB limit.')
    for target, data in copies:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    destination = public / 'content/roasts/manifest.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    pending = destination.with_suffix('.json.tmp')
    pending.write_bytes(manifest_bytes)
    pending.replace(destination)
    return {'status': 'staged locally; not deployed', 'public': str(public),
            'origin_asserted_by_operator': origin, 'manifest_bytes': len(manifest_bytes),
            'files': [str(p.relative_to(public)) for p, _ in copies]
                     + ['content/roasts/manifest.json'],
            'disabled_ids': sorted(ids), 'downloads_enabled': downloads_enabled}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', required=True)
    parser.add_argument('--public', required=True)
    parser.add_argument('--origin', required=True)
    parser.add_argument('--disable-id', action='append', default=[])
    parser.add_argument('--disable-downloads', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(stage(args.release, args.public, args.origin,
                               args.disable_id, not args.disable_downloads), indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'Not staged: {error}\n')
