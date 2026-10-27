"""Reproducible noncreative preparation of generated icon originals.

Crop transparent padding, fit to a real 16px cell with nearest-neighbour
sampling, retain binary alpha and a compact palette. Does not draw artwork.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / "generation_prompts.json").read_text(encoding="utf-8"))
contact = Image.new("RGBA", (5 * 128, 152), "#291538")
draw = ImageDraw.Draw(contact)
for index, asset in enumerate(manifest["assets"]):
    source = Image.open(ROOT / asset["original"]).convert("RGBA")
    opaque = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = opaque.getbbox()
    if bounds is None:
        raise ValueError(f"Empty generated icon: {asset['id']}")
    icon = source.crop(bounds)
    factor = min(14 / icon.width, 14 / icon.height)
    dimensions = (max(1, round(icon.width * factor)), max(1, round(icon.height * factor)))
    icon = icon.resize(dimensions, Image.Resampling.NEAREST)
    icon.putalpha(icon.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    icon = icon.quantize(colors=24, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    cell.alpha_composite(icon, ((16 - icon.width) // 2, (16 - icon.height) // 2))
    destination = ROOT / f"{asset['id']}.png"
    cell.save(destination)
    contact.alpha_composite(cell.resize((112, 112), Image.Resampling.NEAREST), (index * 128 + 8, 8))
    draw.text((index * 128 + 8, 128), asset["id"], fill="#edbc81")
    values = sorted(set(cell.getchannel("A").tobytes()))
    colors = {cell.getpixel((x, y)) for y in range(16) for x in range(16)}
    print(f"{asset['id']}: source={source.size}, native={cell.size}, alpha={values}, colors={len(colors)}")
contact.save(ROOT / "preview_icons.png")
