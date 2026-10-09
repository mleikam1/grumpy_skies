"""Measure unchanged runtime PNGs and create comparison sheets only.

Never edits a runtime asset, removes alpha pixels, or regenerates artwork.
Run with Python and Pillow from any directory.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
MOODS = ['happy', 'excited', 'hyped', 'cozy', 'complaining', 'annoyed',
         'sad', 'worried', 'confident', 'neutral']
PERSONAS = ['karen', 'frat_bro', 'politician', 'grandpa', 'two_year_old']
FONT_PATH = ROOT / 'assets/fonts/daymaker/Roboto-Regular.ttf'
FONT = ImageFont.truetype(str(FONT_PATH), 19)
SMALL = ImageFont.truetype(str(FONT_PATH), 14)

records = {}
for filename in ['generation_manifest.jsonl', 'frat_bro_manifest.jsonl',
                 'grandpa_manifest.jsonl', 'toddler_manifest.jsonl']:
    path = OUT / filename
    if path.exists():
        for line in path.read_text().splitlines():
            if line.strip():
                entry = json.loads(line)
                records[(entry['persona'], entry['mood'])] = entry

metadata = []
missing = []
for persona in PERSONAS:
    for mood in MOODS:
        relative = f'assets/personas/{persona}/{mood}.png'
        path = ROOT / relative
        if not path.exists():
            missing.append(relative)
            continue
        record = records.get((persona, mood), {})
        with Image.open(path) as im:
            alpha = im.getchannel('A') if 'A' in im.getbands() else None
            histogram = alpha.histogram() if alpha else None
            entry = dict(record, path=relative, width=im.width, height=im.height,
                         mode=im.mode, alpha_range=alpha.getextrema() if alpha else None,
                         transparent_pixel_fraction=round(histogram[0] / (im.width * im.height), 5) if alpha else None,
                         sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         bytes=path.stat().st_size, tool='builtin image_gen',
                         classification='new reference-guided emotion edit',
                         alpha_status='native generated alpha retained; minor exterior flecks/fringes remain')
            source = Path(record.get('source', ''))
            if source.is_file():
                entry['matches_generated_source_bytes'] = path.read_bytes() == source.read_bytes()
            metadata.append(entry)

(OUT / 'emotion_asset_metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
(OUT / 'verification.json').write_text(json.dumps(dict(
    expected_count=50, actual_count=len(metadata), missing=missing,
    unique_sha256_count=len({entry['sha256'] for entry in metadata}),
    total_bytes=sum(entry['bytes'] for entry in metadata),
    all_rgba=all(entry['mode'] == 'RGBA' for entry in metadata),
    all_alpha_zero_to_255=all(entry['alpha_range'] == (0, 255) for entry in metadata),
    all_provenance_present=all('prompt' in entry and 'source' in entry for entry in metadata),
    all_sources_unchanged=all(entry.get('matches_generated_source_bytes') for entry in metadata),
    quality_note='Unique files and alpha coverage do not prove clean matting; consult visual review.'
), indent=2) + '\n')

def put(canvas, path, box):
    x, y, w, h = box
    with Image.open(path) as source:
        sprite = source.convert('RGBA')
        sprite.thumbnail((w, h), Image.Resampling.LANCZOS)
        canvas.alpha_composite(sprite, (x + (w - sprite.width)//2, y + (h - sprite.height)//2))

for persona in PERSONAS:
    sheet = Image.new('RGBA', (1440, 560), '#edf0f6')
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), f'{persona.replace("_", " ").title()} / ten moods / light + dark', font=FONT, fill='#152442')
    draw.text((16, 38), 'Asset comparison only, not an app screenshot. Native PNGs unchanged; 128 x 171 logical previews.', font=SMALL, fill='#475873')
    for index, mood in enumerate(MOODS):
        x = 12 + (index % 5) * 286
        y = 74 + (index // 5) * 238
        draw.text((x+4, y), mood, font=FONT, fill='#152442')
        path = ROOT / f'assets/personas/{persona}/{mood}.png'
        for column, color in enumerate(['#fff0f5', '#192940']):
            sx = x + column * 138
            draw.rounded_rectangle((sx, y+31, sx+132, y+210), radius=10, fill=color)
            if path.exists():
                put(sheet, path, (sx+2, y+35, 128, 171))
            else:
                draw.text((sx+8, y+100), 'pending', font=SMALL, fill='#a83a50')
    sheet.convert('RGB').save(OUT / f'{persona}_light_dark.png')

print(json.dumps(dict(count=len(metadata), missing=missing, unique_hashes=len({e['sha256'] for e in metadata}))))
