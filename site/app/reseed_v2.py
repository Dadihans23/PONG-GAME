"""Remplace, sur demande, les textes de la v1 encore en base par ceux de la v2.

Au démarrage, la v2 ajoute ses nouveaux contenus (fiche technique, comparatif,
barème, FAQ, installation, caractéristiques des arguments) sans rien écraser.
Les textes qui existaient déjà (accroche, phrase de téléchargement, arguments,
étapes, légendes des captures, étapes d'installation modifiées, politique de
confidentialité) restent tels quels : cette commande les met à jour, après
confirmation.

    python -m app.reseed_v2              # affiche les changements, ne modifie rien
    python -m app.reseed_v2 --apply      # demande confirmation, puis applique
    python -m app.reseed_v2 --apply --yes

Avec Docker : docker compose exec tilto-site python -m app.reseed_v2 --apply
Les images des captures et les APK ne sont jamais touchés. Faire une sauvegarde
de la base avant (voir README).
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from datetime import date
from pathlib import Path

from . import db

# Réglages dont le texte initial a changé entre la v1 et la v2.
SETTING_KEYS = ("tagline", "download_text")


def _short(value: str, width: int = 70) -> str:
    value = " ".join((value or "").split())
    return value if len(value) <= width else value[: width - 1] + "…"


def plan(conn: sqlite3.Connection) -> list[tuple[str, callable]]:
    """Liste des changements : (description, fonction qui l'applique)."""
    changes: list[tuple[str, callable]] = []
    site = db.get_settings(conn)

    for key in SETTING_KEYS:
        new = db.DEFAULT_SETTINGS[key]
        if site.get(key, "") != new:
            changes.append((
                f"Textes › {key} : « {_short(site.get(key, ''))} » → « {_short(new)} »",
                lambda c, k=key, v=new: c.execute(
                    "UPDATE setting SET value = ? WHERE key = ?", (v, k))))

    features = db.list_items(conn, "feature")
    for pos, v2 in enumerate(db.V2_FEATURES):
        if pos < len(features):
            item = features[pos]
            current = (item["kicker"], item["title"], item["body"], item["short_body"])
            target = (v2["kicker"], v2["title"], v2["body"], v2["short_body"])
            if current != target:
                changes.append((
                    f"Argument {pos + 1} : « {_short(item['title'], 50)} » → texte v2 "
                    f"({v2['kicker']})",
                    lambda c, i=item["id"], t=target: c.execute(
                        "UPDATE content_item SET kicker = ?, title = ?, body = ?, short_body = ?"
                        " WHERE id = ?", (*t, i))))
            specs = [(r["label"], r["value"]) for r in db.list_rows(conn, "feature_spec", item["id"])]
            if specs != list(v2["specs"]):
                def replace_specs(c, i=item["id"], rows=v2["specs"]):
                    c.execute("DELETE FROM spec_row WHERE grp = 'feature_spec' AND item_id = ?", (i,))
                    db._insert_rows(c, "feature_spec", rows, i)
                changes.append((f"Argument {pos + 1} : caractéristiques v2", replace_specs))
        else:
            def add_feature(c, p=pos, f=v2):
                cur = c.execute(
                    "INSERT INTO content_item (kind, position, kicker, title, body, short_body)"
                    " VALUES ('feature', ?, ?, ?, ?, ?)",
                    (db.next_position(c, "content_item", "kind = 'feature'"),
                     f["kicker"], f["title"], f["body"], f["short_body"]))
                db._insert_rows(c, "feature_spec", f["specs"], cur.lastrowid)
            changes.append((f"Argument {pos + 1} ajouté : {v2['kicker']}", add_feature))

    steps = db.list_items(conn, "step")
    for pos, (title, body) in enumerate(db.V2_STEPS):
        if pos < len(steps):
            if (steps[pos]["title"], steps[pos]["body"]) != (title, body):
                what = (f"« {_short(steps[pos]['title'], 50)} » → « {_short(title, 50)} »"
                        if steps[pos]["title"] != title
                        else f"« {_short(title, 50)} » : précision mise à jour")
                changes.append((
                    f"Étape {pos + 1} : {what}",
                    lambda c, i=steps[pos]["id"], t=title, b=body: c.execute(
                        "UPDATE content_item SET title = ?, body = ? WHERE id = ?", (t, b, i))))
        else:
            changes.append((f"Étape {pos + 1} ajoutée : « {_short(title, 50)} »",
                            lambda c, t=title, b=body: c.execute(
                                "INSERT INTO content_item (kind, position, title, body)"
                                " VALUES ('step', ?, ?, ?)",
                                (db.next_position(c, "content_item", "kind = 'step'"), t, b))))

    shots = db.list_screenshots(conn)
    for pos, (caption, description) in enumerate(db.V2_SCREENSHOTS):
        if pos < len(shots):
            if (shots[pos]["caption"], shots[pos]["description"]) != (caption, description):
                changes.append((
                    f"Capture {pos + 1} : « {_short(shots[pos]['caption'], 40)} » → "
                    f"« {caption} » + description (image conservée)",
                    lambda c, i=shots[pos]["id"], t=caption, d=description: c.execute(
                        "UPDATE screenshot SET caption = ?, description = ? WHERE id = ?",
                        (t, d, i))))
        else:
            changes.append((f"Capture {pos + 1} ajoutée sans image : « {caption} »",
                            lambda c, t=caption, d=description: c.execute(
                                "INSERT INTO screenshot (filename, caption, description, position,"
                                " created_at) VALUES (NULL, ?, ?, ?, ?)",
                                (t, d, db.next_position(c, "screenshot"), db.now_iso()))))

    install = [(r["label"], r["value"]) for r in db.list_rows(conn, "install")]
    if install and install != list(db.V2_INSTALL):
        def replace_install(c):
            c.execute("DELETE FROM spec_row WHERE grp = 'install' AND item_id IS NULL")
            db._insert_rows(c, "install", db.V2_INSTALL)
        changes.append(("Installation : étapes v2 (titre + précision) à la place des "
                        f"{len(install)} étapes actuelles", replace_install))

    policy = site.get("privacy_policy", "")
    if "## Formulaire de contact" not in policy:
        def add_contact_section(c, text=policy):
            marker = "## Effacer tes données"
            section = db.PRIVACY_CONTACT_SECTION.strip() + "\n\n"
            new = (text.replace(marker, section + marker, 1) if marker in text
                   else text.rstrip() + "\n\n" + section)
            c.execute("UPDATE setting SET value = ? WHERE key = 'privacy_policy'", (new,))
            c.execute("UPDATE setting SET value = ? WHERE key = 'privacy_updated'",
                      (date.today().isoformat(),))
        changes.append(("Confidentialité : ajout de la section « Formulaire de contact » "
                        "et date de mise à jour à aujourd'hui", add_contact_section))
    return changes


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.reseed_v2", description=__doc__,
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
    # Schéma et contenus v2 à jour (sans effet si le site a déjà démarré en v2).
    db.init_db(path, path.parent / "uploads" / "images")
    conn = db.connect(path)
    try:
        changes = plan(conn)
        if not changes:
            print("Rien à changer : les textes sont déjà ceux de la v2.")
            return 0
        print(f"{len(changes)} changement(s) :")
        for description, _ in changes:
            print(f"  - {description}")
        if not args.apply:
            print("\nAucune modification faite. Relancer avec --apply pour appliquer.")
            return 0
        if not args.yes:
            answer = input("\nAppliquer ces changements ? Tape « oui » pour confirmer : ")
            if answer.strip().lower() != "oui":
                print("Annulé.")
                return 1
        with conn:
            for _, apply in changes:
                apply(conn)
        print("Changements appliqués.")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
