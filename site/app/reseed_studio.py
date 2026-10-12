"""Met à jour la politique de confidentialité EN BASE pour l'appel de l'app au
site (GET /api/app/studio : nom, logo et présentation du studio).

Le texte par défaut (db.PRIVACY_DEFAULT) ne sert qu'à une base neuve : une base
existante garde sa politique. Cette commande, après confirmation :
- ajoute la section « Nom et logo du studio » si elle manque, avant « Ce que
  Tilto n'utilise pas » (sinon avant « Ce site », sinon à la fin) ;
- remplace la phrase des autorisations (« L'accès au réseau Wi-Fi, pour trouver
  et rejoindre une partie en duel. ») si elle est encore mot pour mot celle
  d'origine ;
- met la date de mise à jour de la politique à aujourd'hui.
Rien d'autre n'est touché : un texte modifié autrement reste tel quel.

    python -m app.reseed_studio              # affiche les changements, ne modifie rien
    python -m app.reseed_studio --apply      # demande confirmation, puis applique
    python -m app.reseed_studio --apply --yes

Avec Docker : docker compose exec tilto-site python -m app.reseed_studio --apply
Faire une sauvegarde de la base avant (voir README).
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from datetime import date
from pathlib import Path

from . import db

SECTION_TITLE = "## Nom et logo du studio"
# Titres avant lesquels la section est insérée, dans l'ordre de préférence.
INSERT_BEFORE = ("## Ce que Tilto n'utilise pas", "## Ce site")


def updated_policy(text: str) -> tuple[str, list[str]]:
    """Politique mise à jour et description des changements (liste vide : rien à faire)."""
    changes = []
    if SECTION_TITLE not in text:
        section = db.PRIVACY_STUDIO_SECTION.strip() + "\n\n"
        for marker in INSERT_BEFORE:
            if marker in text:
                text = text.replace(marker, section + marker, 1)
                changes.append(f"section « Nom et logo du studio » ajoutée avant « {marker[3:]} »")
                break
        else:
            text = text.rstrip() + "\n\n" + section.rstrip() + "\n"
            changes.append("section « Nom et logo du studio » ajoutée à la fin")
    if db.PRIVACY_PERMISSIONS_OLD in text:
        text = text.replace(db.PRIVACY_PERMISSIONS_OLD, db.PRIVACY_PERMISSIONS_NEW, 1)
        changes.append("phrase des autorisations : accès au réseau pour le duel et pour "
                       "le nom et le logo du studio")
    return text, changes


def plan(conn: sqlite3.Connection) -> tuple[str, list[str]]:
    return updated_policy(db.get_settings(conn).get("privacy_policy", ""))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.reseed_studio", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="appliquer les changements")
    parser.add_argument("--yes", action="store_true", help="ne pas demander de confirmation")
    parser.add_argument("--db", help="chemin de la base (défaut : $DATA_DIR/tilto.sqlite3)")
    args = parser.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")  # console Windows sans UTF-8

    path = Path(args.db) if args.db else Path(os.environ.get("DATA_DIR", "./data")) / "tilto.sqlite3"
    if not path.is_file():
        print(f"Base introuvable : {path}", file=sys.stderr)
        return 2
    # Schéma et réglages à jour (ajoute studio_about s'il manque, sans rien écraser).
    db.init_db(path, path.parent / "uploads" / "images")
    conn = db.connect(path)
    try:
        policy, changes = plan(conn)
        if not changes:
            print("Rien à changer : la politique de confidentialité parle déjà du nom "
                  "et du logo du studio.")
            return 0
        today = date.today().isoformat()
        print("Politique de confidentialité :")
        for description in changes:
            print(f"  - {description}")
        print(f"  - date de mise à jour : {today}")
        if not args.apply:
            print("\nAucune modification faite. Relancer avec --apply pour appliquer.")
            return 0
        if not args.yes:
            answer = input("\nAppliquer ces changements ? Tape « oui » pour confirmer : ")
            if answer.strip().lower() != "oui":
                print("Annulé.")
                return 1
        db.set_settings(conn, {"privacy_policy": policy, "privacy_updated": today})
        print("Changements appliqués.")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
