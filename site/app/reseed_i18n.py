"""Ajoute EN BASE les traductions anglaises et espagnoles des textes du site.

Une base neuve reçoit ces traductions à sa création. Une base existante (le site
en ligne) n'a d'abord que le français : ses pages /en/ et /es/ affichent alors
les textes modifiables en français (repli), seuls les textes fixes de
l'interface sont traduits. Cette commande, après confirmation :
- cherche, pour chaque texte français traduisible de la base (réglages,
  arguments, étapes, tableaux, FAQ, captures, notes de version, politique de
  confidentialité), sa traduction dans app/content_i18n.py ; elle ne connaît que
  les textes français exacts du contenu initial et ceux relevés sur le site en
  ligne : un texte réécrit par le propriétaire n'est pas traduit (il reste en
  français, à traduire dans l'administration, onglets English / Español) ;
- ajoute seulement les traductions qui MANQUENT : une traduction déjà saisie
  dans l'administration n'est jamais remplacée ;
- ne modifie JAMAIS un texte français (seule la table `translation` est écrite).
Relancée, elle ne fait rien de plus.

    python -m app.reseed_i18n              # affiche les changements, ne modifie rien
    python -m app.reseed_i18n --apply      # demande confirmation, puis applique
    python -m app.reseed_i18n --apply --yes

Avec Docker : docker compose exec tilto-site python -m app.reseed_i18n --apply
Faire une sauvegarde de la base avant (voir README).
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path

from . import db

LANG_NAMES = {"en": "anglais", "es": "espagnol"}
TABLE_NAMES = {
    "setting": "réglage", "content_item": "argument ou étape", "spec_row": "ligne de tableau",
    "faq": "question", "screenshot": "capture", "apk_release": "notes de version",
}


def _short(text: str, width: int = 70) -> str:
    text = " ".join((text or "").split())
    return text if len(text) <= width else text[: width - 1] + "…"


def plan(conn: sqlite3.Connection) -> tuple[list[tuple], list[tuple]]:
    """(traductions à ajouter, textes français sans traduction connue)."""
    additions = db.missing_translations(conn)
    known = {(tbl, row_id, field, lang) for lang, tbl, row_id, field, _, _ in additions}
    unknown = []
    for lang in db.TRANSLATION_LANGS:
        done = db.translated_refs(conn, lang)
        for tbl, row_id, field, french in db.translatable_texts(conn):
            if (tbl, row_id, field) not in done and (tbl, row_id, field, lang) not in known:
                unknown.append((lang, tbl, row_id, field, french))
    return additions, unknown


def apply(conn: sqlite3.Connection, additions: list[tuple]) -> None:
    """Écrit les traductions prévues, sans jamais remplacer une traduction existante
    (vérifié de nouveau dans la transaction)."""
    with conn:
        for lang, tbl, row_id, field, _, translated in additions:
            conn.execute(
                "INSERT OR IGNORE INTO translation (lang, tbl, row_id, field, value)"
                " VALUES (?, ?, ?, ?, ?)", (lang, tbl, row_id, field, translated))


def _label(tbl: str, row_id: int, field: str) -> str:
    if tbl == "setting":
        return f"réglage {field}"
    return f"{TABLE_NAMES.get(tbl, tbl)} n° {row_id}, {field}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.reseed_i18n", description=__doc__,
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
    # Schéma à jour (table translation, colonne contact_message.lang), sans rien écraser.
    db.init_db(path, path.parent / "uploads" / "images")
    conn = db.connect(path)
    try:
        additions, unknown = plan(conn)
        for lang in db.TRANSLATION_LANGS:
            mine = [a for a in additions if a[0] == lang]
            print(f"Traductions en {LANG_NAMES[lang]} à ajouter : {len(mine)}")
            for _, tbl, row_id, field, french, translated in mine:
                print(f"  + {_label(tbl, row_id, field)} : « {_short(french)} »")
                print(f"      -> « {_short(translated)} »")
        if unknown:
            print(f"\nTextes français sans traduction connue (restent en français, à traduire "
                  f"dans l'administration) : {len(unknown)}")
            for lang, tbl, row_id, field, french in unknown:
                print(f"  ? {LANG_NAMES[lang]} · {_label(tbl, row_id, field)} : "
                      f"« {_short(french)} »")
        if not additions:
            print("\nRien à ajouter : toutes les traductions connues sont déjà en base.")
            return 0
        if not args.apply:
            print("\nAucune modification faite. Relancer avec --apply pour appliquer.")
            return 0
        if not args.yes:
            answer = input(f"\nAjouter ces {len(additions)} traductions ? "
                           "Tape « oui » pour confirmer : ")
            if answer.strip().lower() != "oui":
                print("Annulé.")
                return 1
        apply(conn, additions)
        print(f"{len(additions)} traductions ajoutées. Aucun texte français n'a été modifié.")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
