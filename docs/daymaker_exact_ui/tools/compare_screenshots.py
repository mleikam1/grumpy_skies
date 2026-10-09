#!/usr/bin/env python3
"""Compare aligned UI crops without claiming that a pixel metric proves fidelity.

Requires Python 3.10+ and Pillow. Does not access the network or edit input files.
Example:
  python tools/compare_screenshots.py --reference ref.png --candidate app.png \
      --output /tmp/daymaker-comparison

Use --reference-box/--candidate-box x,y,right,bottom to select equivalent regions.
Different pixel densities may use --scale-candidate, which ONLY permits uniform
scaling to the reference dimensions. Different aspect ratios must be recropped.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
try:
    from PIL import Image, ImageChops, ImageEnhance, ImageStat
except ImportError:
    raise SystemExit('Pillow is required. Use a project-local Python environment; do not alter global tools without approval.')


def parse_box(value: str) -> tuple[int, int, int, int]:
    try:
        result = tuple(int(item.strip()) for item in value.split(','))
    except ValueError as exc:
        raise argparse.ArgumentTypeError('Expected four comma-separated integer coordinates.') from exc
    if len(result) != 4 or min(result) < 0 or result[0] >= result[2] or result[1] >= result[3]:
        raise argparse.ArgumentTypeError('Invalid xyxy rectangle; right/bottom must exceed left/top.')
    return result  # type: ignore[return-value]


def load(path: Path, box: tuple[int, int, int, int] | None) -> Image.Image:
    if not path.is_file():
        raise ValueError(f'Image not found: {path}')
    with Image.open(path) as source:
        source.load()
        if box and (box[2] > source.width or box[3] > source.height):
            raise ValueError(f'Crop outside image bounds for {path.name}: {source.size}')
        # Composite alpha onto a neutral solid ground, recording this behavior.
        rgba = source.convert('RGBA')
        ground = Image.new('RGBA', source.size, (255, 255, 255, 255))
        image = Image.alpha_composite(ground, rgba).convert('RGB')
    return image.crop(box) if box else image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-box', type=parse_box)
    parser.add_argument('--candidate-box', type=parse_box)
    parser.add_argument('--scale-candidate', action='store_true')
    args = parser.parse_args()
    try:
        reference = load(args.reference, args.reference_box)
        candidate = load(args.candidate, args.candidate_box)
        original_candidate_size = candidate.size
        scaled = False
        if reference.size != candidate.size:
            if not args.scale_candidate:
                raise ValueError(f'Regions have different dimensions: {reference.size} vs {candidate.size}. '
                                 'Crop equivalent UI regions first; --scale-candidate permits uniform scaling only.')
            scale = reference.width / candidate.width
            if round(candidate.height * scale) != reference.height:
                raise ValueError('Aspect ratios differ. Non-uniform stretching is prohibited; align equivalent crops first.')
            candidate = candidate.resize(reference.size, Image.Resampling.LANCZOS)
            scaled = True
        args.output.mkdir(parents=True, exist_ok=True)
        diff = ImageChops.difference(reference, candidate)
        stat = ImageStat.Stat(diff)
        raw = diff.get_flattened_data() if hasattr(diff, 'get_flattened_data') else diff.getdata()
        over_16 = sum(1 for p in raw if max(p) > 16)
        count = reference.width * reference.height
        side = Image.new('RGB', (reference.width * 2, reference.height), 'white')
        side.paste(reference, (0, 0)); side.paste(candidate, (reference.width, 0))
        side.save(args.output/'side_by_side.png')
        Image.blend(reference, candidate, 0.5).save(args.output/'overlay.png')
        diff.save(args.output/'difference.png')
        ImageEnhance.Brightness(diff).enhance(4).save(args.output/'difference_4x.png')
        report = {
            'reference':str(args.reference), 'candidate':str(args.candidate),
            'reference_box':args.reference_box,'candidate_box':args.candidate_box,
            'comparison_size':list(reference.size),'original_candidate_crop_size':list(original_candidate_size),
            'uniform_resampling_used':scaled,'alpha_composited_on':'white',
            'mean_absolute_channel_error_0_to_255':round(sum(stat.mean)/3,4),
            'fraction_pixels_max_channel_error_above_16':round(over_16/count,6),
            'interpretation':'Diagnostic only. No automatic design-acceptance score. Inspect layout, typography, assets and state. '
                             'Concept boards are generated rasters, not original Flutter goldens. Uniform resampling may affect pixels.'
        }
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,indent=2))
        return 0
    except (OSError, ValueError) as exc:
        print(f'Comparison failed: {exc}', file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
