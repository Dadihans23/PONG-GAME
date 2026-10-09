"""Base SQLite : schéma, contenu initial et accès aux données.

sqlite3 de la bibliothèque standard, sans ORM : quatre tables, des requêtes
courtes et paramétrées, une connexion par requête HTTP.
"""

from __future__ import annotations

import secrets
import shutil
import sqlite3
from collections.abc import Iterator
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS setting (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Arguments (kind = 'feature' : sur-titre, titre, texte) et étapes
-- « Comment jouer » (kind = 'step' : titre, précision ; sur-titre inutilisé).
CREATE TABLE IF NOT EXISTS content_item (
    id       INTEGER PRIMARY KEY,
    kind     TEXT NOT NULL CHECK (kind IN ('feature', 'step')),
    position INTEGER NOT NULL,
    kicker   TEXT NOT NULL DEFAULT '',
    title    TEXT NOT NULL,
    body     TEXT NOT NULL DEFAULT ''
);

-- Captures : légende, image facultative (une capture sans image s'affiche
-- comme un emplacement réservé jusqu'au dépôt de l'image).
CREATE TABLE IF NOT EXISTS screenshot (
    id         INTEGER PRIMARY KEY,
    filename   TEXT UNIQUE,
    caption    TEXT NOT NULL DEFAULT '',
    position   INTEGER NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS apk_release (
    id          INTEGER PRIMARY KEY,
    version     TEXT NOT NULL UNIQUE,
    filename    TEXT NOT NULL UNIQUE,
    size_bytes  INTEGER NOT NULL,
    sha256      TEXT NOT NULL,
    uploaded_at TEXT NOT NULL,
    is_current  INTEGER NOT NULL DEFAULT 0
);

-- Une seule version courante à la fois.
CREATE UNIQUE INDEX IF NOT EXISTS apk_one_current
    ON apk_release (is_current) WHERE is_current = 1;
"""

# Colonnes ajoutées après la création d'une table : (table, colonne, définition).
# init_db les ajoute aux bases existantes ; compléter cette liste à chaque ajout.
MIGRATIONS: list[tuple[str, str, str]] = [
    ("content_item", "kicker", "TEXT NOT NULL DEFAULT ''"),
]

SEED_DIR = Path(__file__).resolve().parent / "seed"
SEED_LOGO = SEED_DIR / "nexora_logo_light.png"

# Texte de la planche 3c de la maquette. Syntaxe : voir render.rich_text.
PRIVACY_DEFAULT = """\
Tilto ne collecte aucune donnée personnelle. Tout ce que le jeu enregistre reste sur ton téléphone.

## Ce que Tilto garde sur ton téléphone

Ton pseudo, tes 10 meilleurs scores, tes statistiques (parties jouées, temps de jeu, meilleure série, victoires et défaites en duel) et tes réglages (sensibilité, son, vibration). Ces informations ne sont jamais envoyées ailleurs.

## Pendant un duel

Les deux téléphones communiquent directement sur votre réseau Wi-Fi local, le temps de la partie : pseudos, position des raquettes et de la balle, score. Rien ne passe par Internet ni par nos serveurs. Nous n'en avons pas.

## Ce que Tilto n'utilise pas

Pas de compte, pas de publicité, pas d'outil de mesure d'audience, pas de localisation.

## Autorisations demandées

L'accès au réseau Wi-Fi, pour trouver et rejoindre une partie en duel. La vibration, pour les renvois. Le capteur de mouvement qui sert à déplacer la raquette ne demande pas d'autorisation.

## Effacer tes données

Désinstalle Tilto, ou va dans Paramètres Android › Applications › Tilto › Stockage › Effacer les données.

## Une question ?

Écris-nous avec le lien Contact en bas de cette page. Tilto est un jeu de Nexora.
"""

DEFAULT_SETTINGS = {
    # Héros
    "game_name": "Tilto",
    "tagline": (
        "Le Pong qu'on joue en inclinant son téléphone. "
        "Seul contre l'ordinateur, ou à deux sur le même Wi-Fi."
    ),
    "hero_note": "Gratuit · Android",
    # Bloc final
    "download_title": "Télécharge Tilto",
    "download_text": "Pour téléphones Android. L'APK s'installe sans le Play Store.",
    # Liens
    "play_store_url": "",
    "contact_email": "",
    # Studio (pied de page)
    "studio_name": "Nexora",
    "studio_logo": "",
    # Confidentialité
    "privacy_updated": "2026-10-09",
    "privacy_policy": PRIVACY_DEFAULT,
}

# (sur-titre, titre, texte) : textes de la planche 3a.
DEFAULT_FEATURES = [
    ("INCLINE", "Pas de bouton. Tu penches, la raquette suit.",
     "Tiens ton téléphone à deux mains et incline-le à gauche ou à droite. "
     "Rien à l'écran ne cache la balle."),
    ("À DEUX", "Chacun son téléphone. Chacun sa raquette en bas.",
     "Mettez-vous sur le même Wi-Fi, ou sur le partage de connexion de l'un de vous : "
     "Tilto trouve la partie tout seul. Pas besoin d'Internet. Le premier à 5 points gagne."),
    ("SENSIBILITÉ", "Réglée pour ta façon de tenir.",
     "Douce pour la précision, vive pour les grands gestes. "
     "Le son et la vibration se règlent aussi, dans les Réglages."),
    ("RECORDS", "Bats ton record. Puis celui des autres.",
     "Le classement garde les 10 meilleurs scores du téléphone. Les statistiques suivent "
     "tes parties, ton temps de jeu, ta meilleure série et tes victoires en duel."),
]

# (titre, précision) : textes de la planche 3a.
DEFAULT_STEPS = [
    ("Prends ton téléphone à deux mains.", "En portrait, l'écran face à toi."),
    ("Tape l'écran.", "La balle part vers l'adversaire."),
    ("Incline pour la renvoyer.",
     "+50 points par renvoi, +100 quand l'adversaire rate. "
     "La balle accélère tous les 4 renvois."),
]

DEFAULT_CAPTIONS = ["Choisis ton mode", "Renvoie, accélère", "Gagne le duel"]


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def connect(db_path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path, timeout=10, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _migrate(conn: sqlite3.Connection) -> None:
    for table, column, definition in MIGRATIONS:
        columns = {r["name"] for r in conn.execute(f"PRAGMA table_info({table})")}
        if column not in columns:
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def _seed_logo(images_dir: Path) -> str:
    """Copie le logo initial du studio dans les données ; renvoie son nom."""
    if not SEED_LOGO.is_file():
        return ""
    images_dir.mkdir(parents=True, exist_ok=True)
    name = f"{secrets.token_hex(16)}.png"
    shutil.copyfile(SEED_LOGO, images_dir / name)
    return name


def init_db(db_path: Path, images_dir: Path) -> None:
    """Crée les tables et, au premier démarrage, le contenu initial.

    Un réglage ajouté plus tard à DEFAULT_SETTINGS est inséré dans les bases
    existantes sans écraser les valeurs déjà modifiées.
    """
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = connect(db_path)
    try:
        conn.execute("PRAGMA journal_mode = WAL")
        conn.executescript(SCHEMA)
        with conn:
            _migrate(conn)
            existing = {r["key"] for r in conn.execute("SELECT key FROM setting")}
            first_run = not existing
            for key, value in DEFAULT_SETTINGS.items():
                if key not in existing:
                    if key == "studio_logo" and first_run:
                        value = _seed_logo(images_dir)
                    conn.execute("INSERT INTO setting (key, value) VALUES (?, ?)", (key, value))
            if first_run:
                for pos, (kicker, title, body) in enumerate(DEFAULT_FEATURES):
                    conn.execute(
                        "INSERT INTO content_item (kind, position, kicker, title, body)"
                        " VALUES ('feature', ?, ?, ?, ?)", (pos, kicker, title, body))
                for pos, (title, body) in enumerate(DEFAULT_STEPS):
                    conn.execute(
                        "INSERT INTO content_item (kind, position, title, body)"
                        " VALUES ('step', ?, ?, ?)", (pos, title, body))
                for pos, caption in enumerate(DEFAULT_CAPTIONS):
                    conn.execute(
                        "INSERT INTO screenshot (filename, caption, position, created_at)"
                        " VALUES (NULL, ?, ?, ?)", (caption, pos, now_iso()))
    finally:
        conn.close()


def get_db(db_path: Path) -> Iterator[sqlite3.Connection]:
    conn = connect(db_path)
    try:
        yield conn
    finally:
        conn.close()


# --- Lecture -----------------------------------------------------------------

def get_settings(conn: sqlite3.Connection) -> dict[str, str]:
    return {r["key"]: r["value"] for r in conn.execute("SELECT key, value FROM setting")}


def set_settings(conn: sqlite3.Connection, values: dict[str, str]) -> None:
    with conn:
        for key, value in values.items():
            if key not in DEFAULT_SETTINGS:
                raise KeyError(key)
            conn.execute(
                "INSERT INTO setting (key, value) VALUES (?, ?)"
                " ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (key, value),
            )


def list_items(conn: sqlite3.Connection, kind: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM content_item WHERE kind = ? ORDER BY position, id", (kind,)
    ).fetchall()


def list_screenshots(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM screenshot ORDER BY position, id").fetchall()


def list_apks(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM apk_release ORDER BY uploaded_at DESC, id DESC").fetchall()


def current_apk(conn: sqlite3.Connection) -> sqlite3.Row | None:
    return conn.execute("SELECT * FROM apk_release WHERE is_current = 1").fetchone()


# --- Ordre des listes ---------------------------------------------------------

def next_position(conn: sqlite3.Connection, table: str, where: str = "1", args: tuple = ()) -> int:
    assert table in {"content_item", "screenshot"}
    row = conn.execute(
        f"SELECT COALESCE(MAX(position), -1) + 1 AS p FROM {table} WHERE {where}", args
    ).fetchone()
    return int(row["p"])


def move(conn: sqlite3.Connection, table: str, row_id: int, direction: int,
         where: str = "1", args: tuple = ()) -> None:
    """Échange l'élément avec son voisin (direction -1 = monter, +1 = descendre)."""
    assert table in {"content_item", "screenshot"}
    ids = [r["id"] for r in conn.execute(
        f"SELECT id FROM {table} WHERE {where} ORDER BY position, id", args
    )]
    if row_id not in ids:
        return
    i = ids.index(row_id)
    j = i + direction
    if not 0 <= j < len(ids):
        return
    ids[i], ids[j] = ids[j], ids[i]
    with conn:
        for pos, item_id in enumerate(ids):
            conn.execute(f"UPDATE {table} SET position = ? WHERE id = ?", (pos, item_id))
