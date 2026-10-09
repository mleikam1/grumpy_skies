#!/usr/bin/env python3
"""Produce diagnostic comparisons without changing either input aspect ratio.

Run after the explicit Flutter fixture capture. Pillow is required. The shipped
reference helper is stricter about exact region ratios; this helper instead
retains full primary screens and labels the reference/candidate canvas padding.
No pixel metric constitutes visual acceptance of a generated concept board.
"""
from pathlib import Path
import json
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageStat

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'docs/daymaker_exact_ui/references/screens'
CANDIDATE = ROOT / 'docs/ui_implementation/screenshots/fixture'
OUTPUT = ROOT / 'docs/ui_implementation/comparisons'
WIDTH = 390
HEADER = 32


def normalized(path):
    with Image.open(path) as source:
        source.load()
        original = source.size
        height = round(source.height * WIDTH / source.width)
        # Uniform scale by width; height rounding is the only rounding applied.
        pixels = source.convert('RGB').resize((WIDTH, height), Image.Resampling.LANCZOS)
    return pixels, original


def compare(theme, screen):
    reference_path = REFERENCE / f'{theme}_{screen}_ui.png'
    candidate_path = CANDIDATE / f'{theme}_{screen}.png'
    reference, reference_original = normalized(reference_path)
    candidate, candidate_original = normalized(candidate_path)
    height = max(reference.height, candidate.height)
    output = OUTPUT / f'{theme}_{screen}'
    output.mkdir(parents=True, exist_ok=True)
    canvases = []
    for pixels in (reference, candidate):
        canvas = Image.new('RGB', (WIDTH, height), '#d1d5db')
        canvas.paste(pixels, (0, 0))
        canvases.append(canvas)
    side = Image.new('RGB', (WIDTH * 2, height + HEADER), 'white')
    draw = ImageDraw.Draw(side)
    draw.text((10, 9), f'APPROVED CONCEPT: {theme} {screen}', fill='black')
    draw.text((WIDTH + 10, 9), f'FLUTTER FIXTURE: {theme} {screen}', fill='black')
    for index, canvas in enumerate(canvases):
        side.paste(canvas, (WIDTH * index, HEADER))
    side.save(output / 'side_by_side.png')
    Image.blend(*canvases, .5).save(output / 'overlay.png')
    diff = ImageChops.difference(*canvases)
    diff.save(output / 'difference.png')
    ImageEnhance.Brightness(diff).enhance(4).save(output / 'difference_4x.png')
    common_height = min(reference.height, candidate.height)
    stat = ImageStat.Stat(diff.crop((0, 0, WIDTH, common_height)))
    report = {
        'reference': str(reference_path.relative_to(ROOT)),
        'candidate': str(candidate_path.relative_to(ROOT)),
        'reference_native_size': reference_original,
        'candidate_native_size': candidate_original,
        'reference_uniformly_scaled_size': reference.size,
        'candidate_uniformly_scaled_size': candidate.size,
        'comparison_canvas_size': [WIDTH, height],
        'reference_bottom_padding_pixels': height - reference.height,
        'candidate_bottom_padding_pixels': height - candidate.height,
        'alignment': 'top-left; full content; uniform scaling only; gray bottom canvas padding',
        'shared_region_mean_absolute_channel_difference': round(sum(stat.mean) / 3, 3),
        'interpretation': 'Diagnostic only; not a match score. Generated dark references have differing geometry. Light reference geometry is authoritative for both app themes. Inspect spacing, typography, colors, content, and artwork manually.',
    }
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    reports = [compare(theme, screen) for theme in ('light', 'dark')
               for screen in ('today', 'roasts', 'fun')]
    (OUTPUT / 'index.json').write_text(json.dumps(reports, indent=2) + '\n')
    print(f'Wrote {len(reports)} comparison sets to {OUTPUT}')
