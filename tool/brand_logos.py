"""Génère les variantes du logo Nexora à partir de assets/nexora.png.

- nexora_logo_light.png : texte bleu nuit -> blanc (fond sombre), symbole intact
- nexora_logo_dark.png  : original recadré (fond clair)
- nexora_mark.png       : symbole « N » seul, recadré

Usage (depuis la racine du projet) : python tool/brand_logos.py
Les aperçus sur fond noir et blanc sont écrits dans build/brand_preview/.
Seuils propres à ce logo (position du symbole, luminosité du texte) : à
revoir si le logo change.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "nexora.png"
OUT = ROOT / "assets" / "brand"
SHOTS = ROOT / "build" / "brand_preview"

MARGIN = 16          # marge transparente autour du contenu (px)
NOISE_ALPHA = 8      # pixels quasi invisibles (bruit de détourage) supprimés
TEXT_START_X = 560   # le mot commence après le symbole (symbole : x 151..529)
DARK_FULL = 90       # luminosité max (V) en dessous : pixel 100 % texte
DARK_NONE = 150      # au-dessus : pixel bleu, conservé


def clean(img):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if 0 < a <= NOISE_ALPHA:
                px[x, y] = (0, 0, 0, 0)
    return img


def crop(img, box=None):
    box = box or img.getbbox()
    l, t, r, b = box
    w, h = img.size
    return img.crop((max(0, l - MARGIN), max(0, t - MARGIN),
                     min(w, r + MARGIN), min(h, b + MARGIN)))


def whiten_text(img):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(TEXT_START_X, w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            v = max(r, g, b)
            t = (DARK_NONE - v) / (DARK_NONE - DARK_FULL)
            if t <= 0:
                continue  # bleu du « x » : conservé
            t = min(1.0, t)
            # Couleur poussée vers le blanc, alpha inchangé (anticrénelage)
            px[x, y] = (round(r + (255 - r) * t), round(g + (255 - g) * t),
                        round(b + (255 - b) * t), a)
    return img


def preview(img, name):
    for bg, label in (((0, 0, 0, 255), "black"), ((255, 255, 255, 255), "white")):
        pad = 40
        canvas = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), bg)
        canvas.alpha_composite(img, (pad, pad))
        canvas.convert("RGB").save(SHOTS / f"preview_{name}_{label}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SHOTS.mkdir(parents=True, exist_ok=True)
    src = clean(Image.open(SRC).convert("RGBA"))

    dark = crop(src)
    dark.save(OUT / "nexora_logo_dark.png", optimize=True)

    light = crop(whiten_text(src.copy()))
    light.save(OUT / "nexora_logo_light.png", optimize=True)

    mark_region = src.crop((0, 0, TEXT_START_X, src.height))
    mark = crop(mark_region)
    mark.save(OUT / "nexora_mark.png", optimize=True)

    for img, name in ((light, "light"), (dark, "dark"), (mark, "mark")):
        print(name, img.size)
        preview(img, name)


if __name__ == "__main__":
    main()
