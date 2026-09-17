#!/usr/bin/env python3
"""Native build gate; reads Dart defines without printing their values/secrets."""
import argparse
import base64
import os
from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TEST_PUBLISHER = '3940256099942544'
UNIT = re.compile(r'^ca-app-pub-\d{16}/\d{10}$')
APP = re.compile(r'^ca-app-pub-\d{16}~\d{10}$')


def decode_defines(raw):
    values = {}
    for item in filter(None, raw.split(',')):
        decoded = base64.b64decode(item).decode()
        key, sep, value = decoded.partition('=')
        if sep:
            values[key] = value
    return values


def validate(values, platform, release, metadata):
    errors = []
    if not APP.fullmatch(metadata or ''):
        errors.append('Native AdMob app metadata must be a valid app ID (with ~).')
    enabled = values.get('DAYMAKER_ADS_ENABLED') == 'true'
    if not enabled:
        return errors
    if not release:
        if values.get('DAYMAKER_TEST_ADS') != 'true':
            errors.append('Development builds must explicitly use DAYMAKER_TEST_ADS=true.')
        return errors
    if values.get('DAYMAKER_TEST_ADS') == 'true':
        errors.append('Test advertising cannot be enabled in a production release.')
    for key in ('DAYMAKER_ADS_READY', 'DAYMAKER_AUDIENCE_DECLARED',
                'DAYMAKER_PRIVACY_READY', 'DAYMAKER_REFRESH_DISABLED'):
        if values.get(key) != 'true':
            errors.append(key + ' must be verified before production activation.')
    if TEST_PUBLISHER in metadata:
        errors.append('Production advertising requires the DayMaker app-specific app ID.')
    all_units = []
    for key in ('DAYMAKER_ANDROID_AD_UNITS', 'DAYMAKER_IOS_AD_UNITS'):
        units = values.get(key, '').split(',')
        if len(units) != 5 or any(not UNIT.fullmatch(v) or TEST_PUBLISHER in v for v in units):
            errors.append(key + ' requires five valid production ad unit IDs.')
        all_units.extend(units)
    if len(set(all_units)) != 10:
        errors.append('All placements and platforms must use distinct production units.')
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['ios', 'android'], required=True)
    parser.add_argument('--mode', default=os.environ.get('CONFIGURATION', 'Debug'))
    parser.add_argument('--defines', default=os.environ.get('DART_DEFINES', ''))
    parser.add_argument('--app-id')
    args = parser.parse_args()
    try:
        values = decode_defines(args.defines)
        metadata = args.app_id
        if args.platform == 'ios':
            with (ROOT / 'ios/Runner/Info.plist').open('rb') as source:
                metadata = plistlib.load(source).get('GADApplicationIdentifier', '')
        errors = validate(values, args.platform, 'release' in args.mode.lower(), metadata)
    except Exception:
        errors = ['Could not validate native monetization build configuration.']
    if errors:
        for error in errors:
            print('error: ' + error, file=sys.stderr)
        return 1
    print('DayMaker monetization build configuration validated; approval/serving is not implied.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
