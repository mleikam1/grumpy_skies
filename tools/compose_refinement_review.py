"""Compose existing QA screenshots without altering application artwork."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'docs/ui_implementation/refinement'
SHOTS = QA / 'screenshots'
FONT = ROOT / 'assets/fonts/daymaker/Roboto-Regular.ttf'
font = ImageFont.truetype(str(FONT), 19)
small = ImageFont.truetype(str(FONT), 15)


def overview():
    tile_width, tile_height = 278, 638
    page = Image.new('RGB', (tile_width * 4 + 40, tile_height * 2 + 86), '#e7edf4')
    draw = ImageDraw.Draw(page)
    draw.text((20, 15), 'DayMaker refinement · Actual app with live weather · October 9, 2026', fill='#10213c', font=font)
    for row, mode in enumerate(('light', 'dark')):
        for col, screen in enumerate(('today', 'details', 'radar', 'roasts')):
            path = SHOTS / f'live_{mode}_{screen}.jpg'
            image = Image.open(path).convert('RGB')
            fitted = ImageOps.contain(image, (tile_width - 14, tile_height - 40), Image.Resampling.LANCZOS)
            x, y = 20 + col * tile_width, 55 + row * tile_height
            draw.text((x, y), f'{screen.title()} · {mode.title()}', fill='#10213c', font=small)
            page.paste(fitted, (x, y + 26))
    page.save(QA / 'live-overview.jpg', quality=94)


def comparisons():
    for before_name, after_name, title in (
        ('details-before.jpg', 'live_light_details.jpg', 'Details: supplied iPhone bug report / refined live app'),
        ('radar-before.jpg', 'live_light_radar.jpg', 'Radar: supplied iPhone bug report / refined live app'),
        ('seven-day-before.jpg', 'live_light_seven_day_bottom.jpg', 'Seven-day sheet: supplied bug report / scrolled live sheet'),
    ):
        page = Image.new('RGB', (850, 980), '#edf2f7')
        draw = ImageDraw.Draw(page)
        draw.text((20, 15), title, fill='#10213c', font=font)
        for x, label, path in ((20, 'Before · supplied iPhone screenshot', QA / 'references' / before_name),
                               (440, 'After · actual browser app, same city', SHOTS / after_name)):
            draw.text((x, 48), label, fill='#425674', font=small)
            image = Image.open(path).convert('RGB')
            fitted = ImageOps.contain(image, (390, 890), Image.Resampling.LANCZOS)
            page.paste(fitted, (x, 77))
        page.save(QA / f'comparison-{before_name.removesuffix("-before.jpg")}.jpg', quality=94)


if __name__ == '__main__':
    overview()
    comparisons()
