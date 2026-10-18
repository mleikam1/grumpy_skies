#!/usr/bin/env python3
"""Deterministically crop/mask the approved source and update existing icon slots.

Requires Pillow. No generative artwork, tracing, color changes, or network IO.
The source is intentionally kept outside Flutter's bundled assets.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/wingman_brand/source/winged_sun_weather_app_icon.png'
LOGO = ROOT / 'assets/brand/wingman_weather_logo.png'
NAVY = (4, 26, 107, 255)


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def fitted(logo, size, opaque=False, scale=1.0):
    # Preserve 841:828 proportions, including high-resolution launcher upscales.
    ratio = size * scale / max(logo.size)
    art = logo.resize((round(logo.width * ratio), round(logo.height * ratio)),
                      Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (size, size), NAVY if opaque else (0, 0, 0, 0))
    canvas.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
    return canvas.convert('RGB') if opaque else canvas


def main():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == (
        'e79dafc98b7a9802c3259264bef771c26e4bfeab8d78b0fb9c28ca6bbc773bd0'
    ), 'Use only the exact approved attachment.'
    source = Image.open(SOURCE).convert('RGB')
    assert source.size == (1254, 1254), 'The approved attachment must not change.'
    # The tile spans these verified scanlines. Exterior shadow starts at y=1024.
    # Find only the saturated blue outer edge; fill the entire interior span so
    # white W/sweep and icy highlights are never mistaken for the pale margin.
    mask = Image.new('L', source.size, 0)
    for y in range(196, 1024):
        boundary = [x for x in range(200, 1055)
                    if source.getpixel((x, y))[0] < 150
                    and source.getpixel((x, y))[2] - source.getpixel((x, y))[0] > 70]
        assert boundary, f'Missing tile boundary on row {y}'
        left, right = min(boundary), max(boundary)
        for x in range(left, right + 1):
            mask.putpixel((x, y), 255)
    bounds = mask.getbbox()
    logo = source.convert('RGBA')
    logo.putalpha(mask)
    logo = logo.crop(bounds)
    save(logo, LOGO)
    # Existing opaque icon asset convention, reused by all current platforms.
    save(fitted(logo, 1024, opaque=True), ROOT / 'assets/brand/app_icon.png')
    contents = json.loads((ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
    for item in contents['images']:
        if 'filename' in item:
            size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
            save(fitted(logo, size, opaque=True), ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset' / item['filename'])
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        save(fitted(logo, size), ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
    for size in (192, 512):
        save(fitted(logo, size), ROOT / f'web/icons/Icon-{size}.png')
        # Maskable icons allow launcher crop; the W/sun/sweep stay in safe circle.
        save(fitted(logo, size, opaque=True, scale=.76), ROOT / f'web/icons/Icon-maskable-{size}.png')
    save(fitted(logo, 32), ROOT / 'web/favicon.png')
    for scale in (1, 2, 3):
        suffix = '' if scale == 1 else f'@{scale}x'
        save(fitted(logo, 168 * scale), ROOT / f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png')
    for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
        save(fitted(logo, round(168 * scale)), ROOT / f'android/app/src/main/res/drawable-{density}/wingman_launch.png')
    # Pixel equality verifies the masking never modifies any retained source RGB.
    interior_count = 0
    for y in range(logo.height):
        for x in range(logo.width):
            r, g, b, alpha = logo.getpixel((x, y))
            if alpha:
                assert (r, g, b) == source.getpixel((x + bounds[0], y + bounds[1]))
                interior_count += 1
    report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'crop_xyxy': bounds, 'derivative_size': logo.size,
              'unchanged_interior_pixels': interior_count,
              'transparent_corners': all(logo.getpixel(p)[3] == 0 for p in
                  [(0, 0), (logo.width-1, 0), (0, logo.height-1), (logo.width-1, logo.height-1)]),
              'ios_icons_opaque': True, 'maskable_art_scale': .76}
    (ROOT / 'docs/wingman_brand/asset_verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
