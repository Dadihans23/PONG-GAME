"""Polices du site (site/app/static/fonts/) : Archivo en WOFF2, sous-ensemble latin.

Source : les TTF de l'app Flutter (assets/fonts/, police Archivo, licence OFL),
qui ne sont pas modifiés. Le site ne sert que les WOFF2 produits ici.

Jeu de caractères gardé : latin de base, Latin-1 (é è ê à ç « » · × …),
Latin étendu A (œ Œ…), ponctuation courante (’ “ ” – — … • ‹ › espaces fines),
€, ™, flèches (← →), signe moins. Avant de restreindre davantage, scanner les
gabarits, db.py et routes_admin.py (le site et l'administration partagent ces
fichiers) et le contenu saisi dans l'administration. Les caractères absents
d'Archivo (↗, ʳ, ᵉ, espace fine insécable U+202F) étaient déjà affichés avec
la police de secours du navigateur.

Outils (hors requirements.txt de production) :
    python -m venv .venv-fonts
    .venv-fonts/Scripts/python -m pip install fonttools brotli
    .venv-fonts/Scripts/python tool/site_fonts.py

Équivalent par fichier en ligne de commande :
    pyftsubset assets/fonts/Archivo-Black.ttf --flavor=woff2 \
        --unicodes="U+0020-007E,U+00A0-017F,..." --layout-features+=tnum,lnum,case \
        --output-file=site/app/static/fonts/Archivo-Black.woff2
"""

from __future__ import annotations

from pathlib import Path

from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "fonts"
TARGET = ROOT / "site" / "app" / "static" / "fonts"
WEIGHTS = ["Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Black"]

UNICODES = ",".join([
    "U+0020-007E",   # latin de base
    "U+00A0-00FF",   # Latin-1 : accents, « » · × ° © espace insécable
    "U+0100-017F",   # Latin étendu A : œ Œ ÿ…
    "U+0192", "U+02C6", "U+02DA", "U+02DC",
    "U+2009-200B",   # espaces fines
    "U+2010-2027",   # tirets, ’ ‘ “ ” „ † • …
    "U+202F", "U+2030", "U+2039-203A", "U+2044",
    "U+20AC",        # €
    "U+2122",        # ™
    "U+2190-2199",   # flèches
    "U+2212",        # signe moins
])

# Fonctions OpenType gardées en plus de celles par défaut de pyftsubset :
# chiffres tabulaires (font-variant-numeric: tabular-nums), chiffres alignés,
# formes adaptées aux capitales.
FEATURES = ["tnum", "lnum", "case"]


def build(weight: str) -> Path:
    source = SOURCE / f"Archivo-{weight}.ttf"
    output = TARGET / f"Archivo-{weight}.woff2"
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = list(options.layout_features) + FEATURES
    options.name_IDs = ["*"]           # garde le nom de la police et la licence
    options.notdef_outline = True
    font = subset.load_font(str(source), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
    subsetter.subset(font)
    subset.save_font(font, str(output), options)
    return output


def main() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    total = 0
    for weight in WEIGHTS:
        out = build(weight)
        size = out.stat().st_size
        total += size
        print(f"{out.relative_to(ROOT)} : {size / 1024:.1f} Ko")
    print(f"Total : {total / 1024:.1f} Ko")


if __name__ == "__main__":
    main()
