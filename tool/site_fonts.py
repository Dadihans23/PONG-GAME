"""Polices du site (site/app/static/fonts/) en WOFF2, sous-ensemble latin.

1. Archivo (marque, titres, sur-titres) : source = les TTF de l'app Flutter
   (assets/fonts/, licence OFL), qui ne sont pas modifiés.
2. Polices de texte (paragraphes, cartes, FAQ, tableau, formulaires), voir
   TEXT_FONTS : les trois candidates comparées pour le site. Chacune est une
   police variable réduite à l'axe des graisses 400-700 (les autres axes figés),
   un seul fichier. Sources : dépôt officiel Google Fonts (licence OFL), à
   télécharger dans un dossier à part, hors du dépôt :
       https://github.com/google/fonts/raw/main/ofl/atkinsonhyperlegiblenext/AtkinsonHyperlegibleNext%5Bwght%5D.ttf
       https://github.com/google/fonts/raw/main/ofl/instrumentsans/InstrumentSans%5Bwdth,wght%5D.ttf
       https://github.com/google/fonts/raw/main/ofl/bricolagegrotesque/BricolageGrotesque%5Bopsz,wdth,wght%5D.ttf
   (et les OFL.txt de chaque dossier). Puis :
       python tool/site_fonts.py --text <dossier des TTF>
   La police choisie se règle dans site.css (variable --font-text).

Le site ne sert que les WOFF2 produits ici.

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
    .venv-fonts/Scripts/python tool/site_fonts.py                 # Archivo
    .venv-fonts/Scripts/python tool/site_fonts.py --text <dossier>  # polices de texte

Équivalent par fichier en ligne de commande :
    pyftsubset assets/fonts/Archivo-Black.ttf --flavor=woff2 \
        --unicodes="U+0020-007E,U+00A0-017F,..." --layout-features+=tnum,lnum,case \
        --output-file=site/app/static/fonts/Archivo-Black.woff2
"""

from __future__ import annotations

import sys
from io import BytesIO
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

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


# Polices de texte : fichier source (police variable Google Fonts) et axes gardés.
# wght de 400 à 700 (regular, semi-gras, gras : les graisses du texte courant) ;
# largeur normale ; Bricolage figée sur sa taille optique « texte » (14).
TEXT_FONTS = {
    "AtkinsonHyperlegibleNext": ("AtkinsonHyperlegibleNext[wght].ttf",
                                 {"wght": (400, 700)}),
    "InstrumentSans": ("InstrumentSans[wdth,wght].ttf",
                       {"wght": (400, 700), "wdth": 100}),
    "BricolageGrotesque": ("BricolageGrotesque[opsz,wdth,wght].ttf",
                           {"wght": (400, 700), "wdth": 100, "opsz": 14}),
}


def subset_options() -> subset.Options:
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = list(options.layout_features) + FEATURES
    options.name_IDs = ["*"]           # garde le nom de la police et la licence
    options.notdef_outline = True
    return options


def subset_and_save(font: TTFont, output: Path, options: subset.Options) -> Path:
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
    subsetter.subset(font)
    subset.save_font(font, str(output), options)
    return output


def build(weight: str) -> Path:
    options = subset_options()
    font = subset.load_font(str(SOURCE / f"Archivo-{weight}.ttf"), options)
    return subset_and_save(font, TARGET / f"Archivo-{weight}.woff2", options)


def build_text(name: str, source_dir: Path) -> Path:
    filename, limits = TEXT_FONTS[name]
    options = subset_options()
    font = instancer.instantiateVariableFont(TTFont(source_dir / filename), limits)
    # Relu depuis la mémoire avant le sous-ensemble (tables variables recalculées).
    buffer = BytesIO()
    font.save(buffer)
    buffer.seek(0)
    font = TTFont(buffer)
    return subset_and_save(font, TARGET / f"{name}.woff2", options)


def report(paths: list[Path]) -> None:
    total = 0
    for out in paths:
        size = out.stat().st_size
        total += size
        print(f"{out.relative_to(ROOT)} : {size / 1024:.1f} Ko")
    print(f"Total : {total / 1024:.1f} Ko")


def main() -> None:
    TARGET.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) == 3 and sys.argv[1] == "--text":
        source_dir = Path(sys.argv[2])
        report([build_text(name, source_dir) for name in TEXT_FONTS])
    else:
        report([build(weight) for weight in WEIGHTS])


if __name__ == "__main__":
    main()
