"""Fichiers de relecture des traductions du site, pour des locuteurs courants.

    python -m app.relecture        # écrit RELECTURE.md et relecture.csv dans site/

Trois sources, dans l'ordre : textes fixes de l'interface (app/i18n.py, UI),
titre et description de l'accueil (app/seo.py), textes de la base
(app/content_i18n.py, ENTRIES). Corriger une traduction : dans le fichier
source, puis relancer cette commande. Pour un texte de la base déjà en ligne,
corriger aussi dans l'administration (onglets English / Español) : la commande
reseed_i18n n'écrase jamais une traduction existante.
"""

from __future__ import annotations

import csv
from pathlib import Path

from . import content_i18n, i18n, seo

SITE_DIR = Path(__file__).resolve().parent.parent

# Remarques sur des textes fixes de l'interface (choix à faire relire).
UI_NOTES = {
    "nav_faq": "Espagnol : « Preguntas » (court pour le menu) ; « FAQ » est compris aussi.",
    "og_alt": "« terrain » : « court » en anglais, « campo » en espagnol (neutre).",
    "official_note": "Phrase des pages légales traduites : la version française fait foi.",
    "contact_lead_end": "Dernier mot de la phrase, gardé sur la même ligne que le point.",
    "count_live": "{used}, {max} : nombres insérés par le script du compteur.",
    "scr_record": "Écran du jeu dessiné ; « BEST » comme dans l'app (glossaire).",
    "court_them": "Étiquette du terrain de démonstration (l'adversaire en solo).",
    "sense_low": "Bornes du curseur de sensibilité, comme dans l'app (Low / Baja).",
    "sense_high": "Bornes du curseur de sensibilité, comme dans l'app (High / Alta).",
    "suggest_text": "Bandeau qui propose la langue du navigateur ; chaque phrase est écrite "
                    "dans la langue proposée.",
}


def rows() -> list[tuple[str, str, str, str, str]]:
    out = []
    for key, texts in i18n.UI.items():
        if not any(texts.values()):
            continue
        out.append((f"ui.{key}", texts["fr"], texts["en"], texts["es"], UI_NOTES.get(key, "")))
    out.append(("seo.home_title", seo.HOME_TITLE_SUFFIXES["fr"], seo.HOME_TITLE_SUFFIXES["en"],
                seo.HOME_TITLE_SUFFIXES["es"], "Titre de l'accueil, après « Tilto : »."))
    out.append(("seo.home_description", seo.HOME_DESCRIPTIONS["fr"], seo.HOME_DESCRIPTIONS["en"],
                seo.HOME_DESCRIPTIONS["es"], "Description pour les moteurs de recherche "
                "(environ 155 caractères)."))
    for where, fr, en, es, note in content_i18n.ENTRIES:
        out.append((f"base.{where}", fr, en, es, note))
    return out


def write(directory: Path = SITE_DIR) -> tuple[Path, Path]:
    data = rows()
    csv_path = directory / "relecture.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["clé", "français", "anglais", "espagnol", "remarque"])
        writer.writerows(data)
    md_path = directory / "RELECTURE.md"
    lines = [
        "# Relecture des traductions du site tilto.fun",
        "",
        "*Fichier généré par `python -m app.relecture` : ne pas le modifier à la main. "
        "Le même contenu est dans `relecture.csv` (tableur).*",
        "",
        "Le français est la langue d'origine et fait foi. Anglais : américain, naturel. "
        "Espagnol : neutre, tutoiement « tú », compris de l'Espagne à l'Amérique latine. "
        "Vocabulaire du jeu : celui de l'app (`lib/l10n/GLOSSAIRE.md` : paddle / paleta, "
        "hit / golpe, high score / récord, Settings / Ajustes, hotspot / punto de acceso…).",
        "",
        "Clés : `ui.*` = textes fixes de l'interface (`app/i18n.py`) ; `seo.*` = titre et "
        "description de l'accueil (`app/seo.py`) ; `base.*` = textes modifiables dans "
        "l'administration, traduits une première fois (`app/content_i18n.py`, ajoutés en ligne "
        "par `python -m app.reseed_i18n`). Une correction d'un texte `base.*` déjà en ligne se "
        "fait aussi dans l'administration, onglet English ou Español.",
        "",
        f"{len(data)} textes.",
        "",
        "| Clé | Français | English | Español | Remarque |",
        "|---|---|---|---|---|",
    ]

    def cell(text: str) -> str:
        return (text or "").replace("|", "\\|").replace("\n", "<br>")

    for key, fr, en, es, note in data:
        lines.append(f"| `{key}` | {cell(fr)} | {cell(en)} | {cell(es)} | {cell(note)} |")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return md_path, csv_path


if __name__ == "__main__":
    for path in write():
        print(f"Écrit : {path}")
