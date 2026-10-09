"""Logo initial du site (site/app/seed/nexora_logo_light.png), réduit.

Le pied de page l'affiche à 24 px de haut : on garde 2 × cette hauteur (48 px,
écrans haute densité) au lieu de l'original 1561 × 339 (144 Ko). Ce fichier ne
sert qu'aux nouvelles installations (copié dans les données au premier
démarrage) ; un site déjà en ligne garde le logo déposé dans l'administration.

Source : assets/brand/nexora_logo_light.png (produit par tool/brand_logos.py).
Usage (Pillow requis) : python tool/site_seed_logo.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "brand" / "nexora_logo_light.png"
TARGET = ROOT / "site" / "app" / "seed" / "nexora_logo_light.png"
HEIGHT = 48  # 2 × la hauteur affichée (CSS .studio-logo, routes_public.LOGO_HEIGHT)


def main() -> None:
    img = Image.open(SOURCE).convert("RGBA")
    width = round(img.width * HEIGHT / img.height)
    small = img.resize((width, HEIGHT), Image.LANCZOS)
    small.save(TARGET, optimize=True)
    print(f"{TARGET.relative_to(ROOT)} : {width} × {HEIGHT}, {TARGET.stat().st_size / 1024:.1f} Ko")


if __name__ == "__main__":
    main()
