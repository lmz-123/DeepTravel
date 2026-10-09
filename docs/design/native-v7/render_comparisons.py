"""Create review sheets from actual Flutter goldens and archived references."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
GOLDENS = ROOT.parents[2] / 'mobile' / 'test' / 'goldens'
FONT = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 16)
canvas = Image.new('RGB', (1312, 1130), '#e8e3d9')
draw = ImageDraw.Draw(canvas)
for i, (name, label) in enumerate([
    ('feed', 'Community'), ('cities', 'City selection'),
    ('detail', 'Post & comments'), ('compose', 'Share a note'),
]):
    image = Image.open(GOLDENS / f'v7-{name}-390.png').convert('RGB')
    image.thumbnail((312, 1080))
    canvas.paste(image, (16 + i * 328, 42))
    draw.text((16 + i * 328, 12), label, fill='#30372d', font=FONT)
canvas.save(ROOT / 'native-preview.png')
for name, source in [('feed', 'feed-top.png'), ('cities', 'cities-top.png')]:
    reference = Image.open(ROOT / 'approved' / source).convert('RGB')
    reference = reference.resize((390, round(reference.height * 390 / reference.width)), Image.Resampling.LANCZOS)
    native = Image.open(GOLDENS / f'v7-{name}-390.png').convert('RGB').crop((0, 0, 390, reference.height))
    canvas = Image.new('RGB', (804, reference.height + 42), '#e8e3d9')
    draw = ImageDraw.Draw(canvas)
    draw.text((0, 12), 'Approved reference', font=FONT, fill='#30372d')
    draw.text((414, 12), 'Flutter implementation', font=FONT, fill='#30372d')
    canvas.paste(reference, (0, 42))
    canvas.paste(native, (414, 42))
    canvas.save(ROOT / f'{name}-comparison.png')
