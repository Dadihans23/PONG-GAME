"""Base SQLite : schéma, contenu initial et accès aux données.

sqlite3 de la bibliothèque standard, sans ORM : quelques tables, des requêtes
courtes et paramétrées, une connexion par requête HTTP.
"""

from __future__ import annotations

import secrets
import shutil
import sqlite3
from collections.abc import Iterator
from datetime import datetime, timezone
from pathlib import Path

from . import content_i18n

SCHEMA = """
CREATE TABLE IF NOT EXISTS setting (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Arguments (kind = 'feature' : sur-titre, titre, texte, texte court mobile)
-- et étapes « Comment jouer » (kind = 'step' : titre, précision).
CREATE TABLE IF NOT EXISTS content_item (
    id         INTEGER PRIMARY KEY,
    kind       TEXT NOT NULL CHECK (kind IN ('feature', 'step')),
    position   INTEGER NOT NULL,
    kicker     TEXT NOT NULL DEFAULT '',
    title      TEXT NOT NULL,
    body       TEXT NOT NULL DEFAULT '',
    short_body TEXT NOT NULL DEFAULT ''
);

-- Captures : légende, description, image facultative (une capture sans image
-- s'affiche comme un emplacement réservé jusqu'au dépôt de l'image).
CREATE TABLE IF NOT EXISTS screenshot (
    id          INTEGER PRIMARY KEY,
    filename    TEXT UNIQUE,
    caption     TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    position    INTEGER NOT NULL,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS apk_release (
    id            INTEGER PRIMARY KEY,
    version       TEXT NOT NULL UNIQUE,
    filename      TEXT NOT NULL UNIQUE,
    size_bytes    INTEGER NOT NULL,
    sha256        TEXT NOT NULL,
    uploaded_at   TEXT NOT NULL,
    is_current    INTEGER NOT NULL DEFAULT 0,
    release_notes TEXT NOT NULL DEFAULT '',
    release_date  TEXT NOT NULL DEFAULT ''
);

-- Une seule version courante à la fois.
CREATE UNIQUE INDEX IF NOT EXISTS apk_one_current
    ON apk_release (is_current) WHERE is_current = 1;

-- Lignes ordonnées libellé / valeur(s), regroupées par « grp » (voir TABLE_GROUPS) :
-- fiche technique, comparatif Solo / Duel (value = Solo, value2 = Duel), barème,
-- étapes d'installation de l'APK (label = titre, value = précision) et
-- caractéristiques d'un argument (item_id = l'argument).
CREATE TABLE IF NOT EXISTS spec_row (
    id       INTEGER PRIMARY KEY,
    grp      TEXT NOT NULL,
    item_id  INTEGER REFERENCES content_item (id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    label    TEXT NOT NULL DEFAULT '',
    value    TEXT NOT NULL DEFAULT '',
    value2   TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS spec_row_grp ON spec_row (grp, item_id, position);

-- Questions fréquentes. anchor = identifiant HTML stable (lien /#anchor) ;
-- footer_label : n'est plus utilisé (l'ancienne rubrique « Aide » du pied de page).
CREATE TABLE IF NOT EXISTS faq (
    id           INTEGER PRIMARY KEY,
    position     INTEGER NOT NULL,
    anchor       TEXT NOT NULL UNIQUE,
    question     TEXT NOT NULL,
    answer       TEXT NOT NULL DEFAULT '',
    short_answer TEXT NOT NULL DEFAULT '',
    footer_label TEXT NOT NULL DEFAULT ''
);

-- Messages du formulaire de contact. Aucune adresse IP n'est enregistrée.
CREATE TABLE IF NOT EXISTS contact_message (
    id         INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL,
    name       TEXT NOT NULL DEFAULT '',
    email      TEXT NOT NULL,
    subject    TEXT NOT NULL,
    message    TEXT NOT NULL,
    is_read    INTEGER NOT NULL DEFAULT 0
);

-- Traductions anglaise et espagnole des textes modifiables. Le français reste
-- dans les tables d'origine et sert de repli : une traduction vide n'est pas
-- enregistrée. tbl = 'setting' (row_id 0, field = clé du réglage) ou le nom de la
-- table du texte (row_id = son id, field = sa colonne).
CREATE TABLE IF NOT EXISTS translation (
    lang   TEXT NOT NULL CHECK (lang IN ('en', 'es')),
    tbl    TEXT NOT NULL,
    row_id INTEGER NOT NULL DEFAULT 0,
    field  TEXT NOT NULL,
    value  TEXT NOT NULL,
    PRIMARY KEY (lang, tbl, row_id, field)
);

-- Un texte supprimé emporte ses traductions (y compris les caractéristiques
-- supprimées en cascade avec leur argument).
CREATE TRIGGER IF NOT EXISTS translation_content_item AFTER DELETE ON content_item
BEGIN DELETE FROM translation WHERE tbl = 'content_item' AND row_id = OLD.id; END;
CREATE TRIGGER IF NOT EXISTS translation_spec_row AFTER DELETE ON spec_row
BEGIN DELETE FROM translation WHERE tbl = 'spec_row' AND row_id = OLD.id; END;
CREATE TRIGGER IF NOT EXISTS translation_faq AFTER DELETE ON faq
BEGIN DELETE FROM translation WHERE tbl = 'faq' AND row_id = OLD.id; END;
CREATE TRIGGER IF NOT EXISTS translation_screenshot AFTER DELETE ON screenshot
BEGIN DELETE FROM translation WHERE tbl = 'screenshot' AND row_id = OLD.id; END;
CREATE TRIGGER IF NOT EXISTS translation_apk_release AFTER DELETE ON apk_release
BEGIN DELETE FROM translation WHERE tbl = 'apk_release' AND row_id = OLD.id; END;
"""

# Colonnes ajoutées après la création d'une table : (table, colonne, définition).
# init_db les ajoute aux bases existantes ; compléter cette liste à chaque ajout.
MIGRATIONS: list[tuple[str, str, str]] = [
    ("content_item", "kicker", "TEXT NOT NULL DEFAULT ''"),
    # Site v2
    ("content_item", "short_body", "TEXT NOT NULL DEFAULT ''"),
    ("screenshot", "description", "TEXT NOT NULL DEFAULT ''"),
    ("apk_release", "release_notes", "TEXT NOT NULL DEFAULT ''"),
    ("apk_release", "release_date", "TEXT NOT NULL DEFAULT ''"),
    # Site multilingue : langue de la page d'où le message a été envoyé.
    ("contact_message", "lang", "TEXT NOT NULL DEFAULT 'fr'"),
]

SEED_DIR = Path(__file__).resolve().parent / "seed"
SEED_LOGO = SEED_DIR / "nexora_logo_light.png"

# Section ajoutée à la politique de confidentialité avec le formulaire de contact.
PRIVACY_CONTACT_SECTION = """\
## Formulaire de contact

Si tu nous écris avec le formulaire de la page Contact, nous recevons ton adresse e-mail, le sujet choisi, ton message et, si tu l'indiques, ton nom. Ces informations servent uniquement à te répondre : elles ne sont ni vendues, ni partagées, ni utilisées pour t'envoyer de la publicité. Elles sont conservées jusqu'à ce que nous supprimions le message. Une copie peut nous être transmise par e-mail pour que nous la voyions plus vite. La page Contact dépose un cookie technique de sécurité, effacé à la fermeture du navigateur ; il ne sert pas à te suivre.
"""

# Section ajoutée à la politique de confidentialité quand l'app a commencé à
# demander au site le nom et le logo du studio (GET /api/app/studio).
PRIVACY_STUDIO_SECTION = """## Nom et logo du studio

Au lancement, et au plus une fois par jour, Tilto demande à tilto.fun le nom, le logo et la présentation du studio, pour les afficher dans l'app. Cette demande ne contient aucune donnée personnelle et rien sur ta façon de jouer. Comme pour toute visite d'un site, notre serveur voit l'adresse IP du téléphone (voir « Ce site »). Sans Internet, l'app affiche simplement le dernier logo connu.
"""

# Phrase « Autorisations demandées » d'avant l'appel au site, et sa version à jour.
PRIVACY_PERMISSIONS_OLD = "L'accès au réseau Wi-Fi, pour trouver et rejoindre une partie en duel."
PRIVACY_PERMISSIONS_NEW = ("L'accès au réseau : le Wi-Fi local, pour trouver et rejoindre une partie "
                           "en duel, et Internet, pour récupérer le nom et le logo du studio.")

# Texte de la planche 3c de la maquette. Syntaxe : voir render.rich_text.
PRIVACY_DEFAULT = """\
Tilto ne collecte aucune donnée personnelle. Tout ce que le jeu enregistre reste sur ton téléphone.

## Ce que Tilto garde sur ton téléphone

Ton pseudo, tes 10 meilleurs scores, tes statistiques (parties jouées, temps de jeu, meilleure série, victoires et défaites en duel) et tes réglages (sensibilité, son, vibration). Ces informations ne sont jamais envoyées ailleurs.

## Pendant un duel

Les deux téléphones communiquent directement sur votre réseau Wi-Fi local, le temps de la partie : pseudos, position des raquettes et de la balle, score. Rien ne passe par Internet ni par nos serveurs.

""" + PRIVACY_STUDIO_SECTION + """
## Ce que Tilto n'utilise pas

Pas de compte, pas de publicité, pas d'outil de mesure d'audience, pas de localisation.

## Autorisations demandées

""" + PRIVACY_PERMISSIONS_NEW + """ La vibration, pour les renvois. Le capteur de mouvement qui sert à déplacer la raquette ne demande pas d'autorisation.

## Ce site

Comme tout site web, notre serveur enregistre des journaux techniques pour chaque visite : adresse IP, date et heure, page demandée et type de navigateur. Ils servent uniquement à faire fonctionner le site, à le sécuriser et à corriger les erreurs. Ils ne sont ni vendus ni partagés, et ne sont conservés que pour une durée limitée. Le site ne dépose aucun cookie de suivi.

""" + PRIVACY_CONTACT_SECTION + """
## Effacer tes données

Désinstalle Tilto, ou va dans Paramètres Android › Applications › Tilto › Stockage › Effacer les données.

## Une question ?

Écris-nous avec le formulaire de la page Contact (lien en bas de chaque page). Tilto est un jeu de Nexora.
"""

# Champs des mentions légales : clé -> (libellé, obligatoire).
LEGAL_FIELDS: dict[str, tuple[str, bool]] = {
    "legal_publisher": ("Éditeur : nom ou raison sociale", True),
    "legal_form": ("Forme juridique (ex. entrepreneur individuel, SAS…)", True),
    "legal_registration": ("Numéro d'immatriculation (SIREN, RCS…), facultatif", False),
    "legal_address": ("Adresse de l'éditeur", True),
    "legal_email": ("E-mail de l'éditeur", True),
    "legal_phone": ("Téléphone de l'éditeur, facultatif", False),
    "legal_director": ("Directeur de la publication", True),
    "legal_host_name": ("Hébergeur : nom", True),
    "legal_host_address": ("Hébergeur : adresse", True),
    "legal_host_phone": ("Hébergeur : téléphone", True),
}

DEFAULT_SETTINGS = {
    # Haut de page (héros)
    "game_name": "Tilto",
    "hero_kicker": "PONG VERTICAL · ANDROID · SOLO ET DUEL LOCAL",
    "tagline": "Le Pong qu'on joue en inclinant son téléphone.",
    "hero_text": (
        "Ta raquette est en bas, celle de l'adversaire en haut. Pas de bouton à l'écran : "
        "tu tiens le téléphone à deux mains et tu le penches à gauche ou à droite. "
        "Joue seul contre l'ordinateur sur trois niveaux, ou défie un ami en duel. "
        "Chacun joue sur son téléphone, sur le même Wi-Fi, sans Internet."
    ),
    "hero_text_short": (
        "Pas de bouton : tu penches le téléphone et ta raquette suit. Seul contre "
        "l'ordinateur, ou à deux sur le même Wi-Fi, sans Internet."
    ),
    "hero_demo_text": (
        "Partie de démonstration. En jeu, ta raquette suit l'inclinaison du téléphone, "
        "et la balle accélère tous les 4 renvois."
    ),
    "hero_note": "Gratuit · Android",
    # Pastille à côté du grand titre (maquette « Néon magenta »). Vide = masquée.
    "hero_badge": "1 vs 1",
    # Section « Le jeu » (arguments)
    "features_kicker": "CE QUI CHANGE DU PONG CLASSIQUE",
    "features_title": "Quatre idées, poussées jusqu'au bout.",
    "features_intro": (
        "Tilto garde la règle du Pong : renvoyer la balle et ne pas la laisser passer. "
        "Ce qui change, c'est la façon de jouer. Ici, ce sont tes mains et le téléphone "
        "tout entier qui servent de manette, et le duel se joue sans réseau mobile ni compte."
    ),
    # Scène « Face-à-face » (section Solo ou Duel, au-dessus du comparatif).
    # Dans l'app, chaque joueur voit SA raquette en bas, en bleu, et l'adversaire
    # en haut, en vert : les téléphones dessinés suivent cette règle.
    "duel_kicker": "FACE-À-FACE · DUEL · PREMIER À 5",
    "duel_title": "Chacun son téléphone,",
    "duel_title_accent": "chacun sa raquette en bas.",
    "duel_left_label": "TÉLÉPHONE DE LÉA",
    "duel_left_name": "Léa",
    "duel_left_score": "2",
    "duel_left_text": "Léa se voit en bas, en bleu. Tom est en haut, en vert.",
    "duel_right_label": "TÉLÉPHONE DE TOM",
    "duel_right_name": "Tom",
    "duel_right_score": "3",
    "duel_right_text": (
        "Sur son écran, c'est Tom qui est en bas, en bleu. Le premier à 5 gagne."
    ),
    "duel_chip_1": "Même Wi-Fi ou partage de connexion",
    "duel_chip_2": "Les deux « Prêt », puis 3-2-1",
    "duel_chip_3": "Revanche en un bouton",
    # Comparatif Solo / Duel
    "compare_kicker": "SOLO OU DUEL",
    "compare_title": "Deux façons de jouer, mêmes règles de base.",
    # Comment jouer et barème
    "steps_title": "Comment jouer",
    "scoring_title": "Barème en solo",
    # Captures
    "screens_title": "Captures",
    "screens_intro": "À quoi ça ressemble sur ton téléphone.",
    "screens_note": "Captures réelles · Android, 360 × 800",
    # FAQ
    "faq_title": "Questions fréquentes",
    "faq_subtitle": "Avant de télécharger.",
    "faq_text": "Une autre question ? Écris-nous avec le formulaire de contact.",
    # Bloc final, installation, nouveautés
    "download_title": "Télécharge Tilto",
    "download_text": (
        "Le Play Store installe les mises à jour tout seul. L'APK sert si tu n'as pas "
        "le Play Store ou si tu veux l'installer à la main."
    ),
    "install_title": "Installer l'APK",
    "install_note": (
        "L'APK n'est pas signé avec la même clé que la version du Play Store : pour passer "
        "de l'un à l'autre, il faudra désinstaller Tilto, et tes scores seront perdus."
    ),
    "notes_title": "Nouveautés",
    # Liens
    "play_store_url": "",
    # Sous « Google Play », sur le bouton non cliquable affiché tant que le lien est vide.
    "play_soon_text": "Bientôt disponible",
    "contact_email": "",
    # Pied de page
    "footer_text": (
        "Le Pong qu'on joue en inclinant son téléphone, seul ou à deux sur le même Wi-Fi. "
        "Gratuit, sans pub, sans compte."
    ),
    "footer_note": "Aucune donnée personnelle collectée · tout reste sur ton téléphone",
    "footer_trademark": "Android est une marque de Google LLC.",
    # Studio (pied de page du site, page Le studio de l'app)
    "studio_name": "Nexora",
    "studio_logo": "",
    # Présentation du studio, affichée dans l'app (page Le studio). Vide par défaut.
    "studio_about": "",
    # Confidentialité
    "privacy_updated": "2026-10-12",
    "privacy_policy": PRIVACY_DEFAULT,
    # Mentions légales (l'hébergeur est pré-rempli ; adresse et téléphone à vérifier)
    **{key: "" for key in LEGAL_FIELDS},
    "legal_host_name": "Contabo GmbH",
    "legal_extra": "",
    "legal_updated": "",
}

# --- Langues -----------------------------------------------------------------------

# Langues des traductions (le français est dans les tables d'origine).
TRANSLATION_LANGS = ("en", "es")

# Réglages traduisibles. Les autres valent pour les trois langues : nom du jeu,
# liens, adresse de contact, pseudos et scores de la scène du duel (des noms et
# des chiffres), nom et logo du studio, dates, données des mentions légales.
TRANSLATABLE_SETTINGS = (
    "hero_kicker", "tagline", "hero_text", "hero_text_short", "hero_demo_text", "hero_note",
    "hero_badge", "features_kicker", "features_title", "features_intro",
    "duel_kicker", "duel_title", "duel_title_accent", "duel_left_label", "duel_left_text",
    "duel_right_label", "duel_right_text", "duel_chip_1", "duel_chip_2", "duel_chip_3",
    "compare_kicker", "compare_title", "steps_title", "scoring_title",
    "screens_title", "screens_intro", "screens_note", "faq_title", "faq_subtitle", "faq_text",
    "download_title", "download_text", "install_title", "install_note", "notes_title",
    "play_soon_text", "footer_text", "footer_note", "footer_trademark",
    "studio_about", "privacy_policy", "legal_extra",
)

# Colonnes traduisibles des tables (le reste : ordre, ancres, fichiers, dates).
TRANSLATABLE_COLUMNS: dict[str, tuple[str, ...]] = {
    "content_item": ("kicker", "title", "body", "short_body"),
    "spec_row": ("label", "value", "value2"),
    "faq": ("question", "answer", "short_answer"),
    "screenshot": ("caption", "description"),
    "apk_release": ("release_notes",),
}

# Réglages internes (non modifiables depuis l'administration).
SEED_V2_MARKER = "_seed_v2"

# --- Contenu initial v2 (maquette « Tilto Site v2 », corrigée) -----------------

# kicker, titre, texte, texte court mobile, caractéristiques (libellé, valeur)
V2_FEATURES: list[dict] = [
    {
        "kicker": "INCLINE",
        "title": "Pas de bouton. Tu penches, la raquette suit.",
        "body": (
            "L'accéléromètre lit l'angle du téléphone en continu. Plus tu penches, plus "
            "la raquette va vite. Tes pouces ne couvrent jamais l'écran, et rien n'est posé "
            "sur le terrain : le bouton pause reste dans la bande du haut."
        ),
        "short_body": (
            "Plus tu penches, plus la raquette va vite. Tes pouces ne couvrent jamais "
            "l'écran. Son et vibration à chaque renvoi."
        ),
        "specs": [
            ("Prise en main", "À deux mains, en portrait"),
            ("Retour", "Son et vibration à chaque renvoi"),
            ("Démarrage", "Tape n'importe où"),
            ("Pause", "En solo uniquement"),
        ],
    },
    {
        "kicker": "À DEUX",
        "title": "Chacun son téléphone, chacun sa raquette en bas.",
        "body": (
            "L'un crée la partie, l'autre la voit apparaître dans sa liste et la rejoint. "
            "Il n'y a pas d'adresse IP à taper, ni de compte ou de code à partager. Les deux "
            "téléphones se parlent directement sur le Wi-Fi de la maison, ou sur le partage "
            "de connexion de l'un de vous, même sans forfait data."
        ),
        "short_body": (
            "L'un crée la partie, l'autre la voit apparaître et la rejoint. Les téléphones "
            "se parlent directement, même sans forfait data."
        ),
        "specs": [
            ("Format", "Premier à 5 points"),
            ("Réseau", "Même Wi-Fi ou partage de connexion"),
            ("Lancement", "Les deux « Prêt », puis 3-2-1"),
            ("Revanche", "Un bouton, sans repasser par le menu"),
        ],
    },
    {
        "kicker": "SENSIBILITÉ",
        "title": "Réglée pour ta façon de tenir.",
        "body": (
            "Certains jouent à petits gestes, d'autres font tourner tout le téléphone. "
            "Le curseur de sensibilité adapte la vitesse de la raquette à l'angle. Tu le "
            "règles une fois et il reste mémorisé. La musique, les effets sonores et la "
            "vibration ont chacun leur interrupteur."
        ),
        "short_body": (
            "De douce à vive, mémorisée une fois pour toutes. Musique, effets sonores et "
            "vibration ont chacun leur interrupteur."
        ),
        "specs": [
            ("Sensibilité", "De douce à vive"),
            ("Son", "Musique et effets, activés ou coupés"),
            ("Vibration", "Activée ou coupée"),
            ("Où", "Accueil › Réglages"),
        ],
    },
    {
        "kicker": "RECORDS",
        "title": "Bats ton record, puis celui de la famille.",
        "body": (
            "Le classement garde les 10 meilleurs scores joués sur le téléphone, avec le "
            "pseudo et la date. Quand quelqu'un bat le record pendant une partie, le terrain "
            "passe à l'or. Les statistiques comptent tes parties, ton temps de jeu, ta "
            "meilleure série de renvois et ton bilan en duel."
        ),
        "short_body": (
            "Top 10 du téléphone avec pseudo et date. Statistiques : parties, temps de jeu, "
            "meilleure série, bilan en duel."
        ),
        "specs": [
            ("Classement", "Top 10 local"),
            ("Statistiques", "Parties, temps, série, duels"),
            ("Accès", "Depuis l'accueil, à tout moment"),
            ("Stockage", "Sur le téléphone, jamais en ligne"),
        ],
    },
]

# (titre, précision)
V2_STEPS = [
    ("Prends ton téléphone à deux mains.",
     "En portrait, l'écran face à toi, à plat ou légèrement relevé. "
     "Sur l'accueil, choisis Solo ou Multijoueur."),
    ("Tape l'écran pour lancer la balle.",
     "En duel, pas besoin : un compte à rebours 3-2-1 lance la balle sur les deux "
     "téléphones en même temps."),
    ("Incline pour la renvoyer.",
     "Penche vers la gauche ou la droite pour placer ta raquette sous la balle. "
     "Ne la laisse pas passer derrière toi."),
]

# (légende, description)
V2_SCREENSHOTS = [
    ("L'accueil",
     "Choisis Solo ou Multijoueur, et en solo la difficulté : Facile, Normal ou Difficile. "
     "Le classement, les statistiques et les réglages sont à portée de pouce."),
    ("En solo",
     "Le score reste discret, la balle en vedette. La jauge de vitesse, en haut, annonce "
     "la prochaine accélération."),
    ("En duel",
     "Chaque score est de son côté, dans sa couleur. Le premier à 5 points gagne."),
    ("Fin du duel",
     "Score final, durée, plus long échange. Un bouton pour la revanche, l'autre joueur "
     "n'a qu'à accepter."),
]

V2_HERO_SPECS = [
    ("MODES", "Solo · Duel"),
    ("JOUEURS", "1 ou 2"),
    ("INTERNET", "Jamais requis"),
    ("ANDROID", "5.0 et plus"),
    ("PRIX", "Gratuit"),
]

# (critère, Solo, Duel)
V2_COMPARE = [
    ("Adversaire", "L'ordinateur", "Un ami, sur son téléphone"),
    ("Niveaux", "Facile, Normal, Difficile", "Le niveau de ton ami"),
    ("But", "Le plus gros score possible", "Arriver le premier à 5 points"),
    ("Fin de partie", "La balle passe derrière toi", "Un joueur atteint 5 points"),
    ("Pause", "Oui, avec musique", "Non, le duel ne s'arrête pas"),
    ("Réseau", "Aucun, même en mode avion", "Même Wi-Fi ou partage de connexion, sans Internet"),
    ("Compte dans", "Classement, statistiques", "Victoires et défaites"),
]

V2_SCORING = [
    ("Chaque renvoi", "+50"),
    ("L'ordinateur rate la balle", "+100"),
    ("La balle accélère", "tous les 4 renvois"),
]

# Étapes d'installation de l'APK : (titre, précision).
V2_INSTALL = [
    ("Télécharge le fichier", "Depuis ton téléphone Android."),
    ("Ouvre-le", "Si Android le demande, autorise ton navigateur à installer des applications."),
    ("Installe", "Touche Installer, puis Ouvrir."),
]

# Ancien texte par défaut des étapes (une seule colonne) -> (titre, précision).
# Une étape encore identique à ce texte est découpée au démarrage ; une étape
# modifiée par le propriétaire n'est jamais touchée.
INSTALL_SPLIT = dict(zip([
    "Télécharge le fichier depuis ton téléphone Android.",
    "Ouvre-le. Si Android le demande, autorise ton navigateur à installer des applications.",
    "Touche Installer, puis Ouvrir.",
], V2_INSTALL))

# anchor, question, réponse, réponse courte (mobile), libellé du lien de pied de page
V2_FAQ: list[dict] = [
    {"anchor": "internet", "question": "Faut-il Internet pour jouer ?",
     "answer": "Non. Le solo marche même en mode avion. Le duel a juste besoin que les deux "
               "téléphones soient sur le même Wi-Fi ou partage de connexion.",
     "short_answer": "Non. Le solo marche en mode avion, le duel a juste besoin du même Wi-Fi.",
     "footer_label": ""},
    {"anchor": "iphone", "question": "Mon ami a un iPhone, on peut jouer ?",
     "answer": "Pas encore : Tilto existe uniquement sur Android pour l'instant. "
               "Le duel demande Tilto sur les deux téléphones.",
     "short_answer": "Pas encore : Tilto existe uniquement sur Android pour l'instant.",
     "footer_label": ""},
    {"anchor": "duel-connexion", "question": "Le duel ne trouve pas la partie de mon ami.",
     "answer": "Vérifiez que vous êtes sur le même réseau (pas un Wi-Fi invité), que ton ami "
               "a bien touché « Créer une partie », puis touche Actualiser.",
     "short_answer": "Même réseau (pas un Wi-Fi invité), « Créer une partie » côté ami, "
                     "puis Actualiser.",
     "footer_label": "Le duel ne se connecte pas"},
    {"anchor": "petit-telephone", "question": "Ça marche sur un petit téléphone ?",
     "answer": "Oui. Le terrain s'adapte à la taille de l'écran, et Tilto fonctionne à partir "
               "d'Android 5.0.",
     "short_answer": "", "footer_label": ""},
    {"anchor": "pubs-achats", "question": "Y a-t-il des achats ou des pubs ?",
     "answer": "Non. Tilto est gratuit, sans publicité, sans achat intégré et sans compte.",
     "short_answer": "Aucun. Gratuit, sans compte.", "footer_label": ""},
    {"anchor": "sensibilite", "question": "La raquette part toute seule.",
     "answer": "La raquette suit l'inclinaison gauche-droite du téléphone : tiens-le bien droit, "
               "sans le pencher sur le côté, et elle s'arrête. Si elle reste trop vive, baisse "
               "la sensibilité dans Accueil › Réglages.",
     "short_answer": "", "footer_label": "Régler la sensibilité"},
]

# Notes de la version 1.0.0 (une ligne par nouveauté).
V2_RELEASE_NOTES_1_0_0 = "\n".join([
    "Solo contre l'ordinateur, sur trois niveaux : Facile, Normal, Difficile.",
    "Mode Duel : deux téléphones sur le même Wi-Fi, premier à 5 points.",
    "Classement des 10 meilleurs scores et statistiques, depuis l'accueil.",
    "Réglages : sensibilité, musique, effets sonores et vibration.",
    "Fin de partie avec « Nouveau record ».",
])

# Groupes possibles de spec_row.
TABLE_GROUPS = {"hero_spec", "compare", "scoring", "install", "feature_spec"}


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


def _insert_rows(conn: sqlite3.Connection, grp: str, rows, item_id: int | None = None) -> None:
    for pos, row in enumerate(rows):
        if isinstance(row, str):
            row = (row,)
        label, value, value2 = (tuple(row) + ("", ""))[:3]
        conn.execute(
            "INSERT INTO spec_row (grp, item_id, position, label, value, value2)"
            " VALUES (?, ?, ?, ?, ?, ?)", (grp, item_id, pos, label, value, value2))


def _group_empty(conn: sqlite3.Connection, grp: str) -> bool:
    return conn.execute("SELECT 1 FROM spec_row WHERE grp = ? LIMIT 1", (grp,)).fetchone() is None


def _seed_v2(conn: sqlite3.Connection) -> None:
    """Contenus ajoutés par la v2 du site, insérés une seule fois et seulement
    là où rien n'existe : rien de ce qui est déjà en base n'est écrasé."""
    for grp, rows in (("hero_spec", V2_HERO_SPECS), ("compare", V2_COMPARE),
                      ("scoring", V2_SCORING), ("install", V2_INSTALL)):
        if _group_empty(conn, grp):
            _insert_rows(conn, grp, rows)
    if conn.execute("SELECT 1 FROM faq LIMIT 1").fetchone() is None:
        for pos, f in enumerate(V2_FAQ):
            conn.execute(
                "INSERT INTO faq (position, anchor, question, answer, short_answer, footer_label)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (pos, f["anchor"], f["question"], f["answer"], f["short_answer"],
                 f["footer_label"]))
    # Caractéristiques et texte court : rattachés aux arguments existants par leur
    # sur-titre, seulement s'ils n'en ont pas encore.
    by_kicker = {f["kicker"]: f for f in V2_FEATURES}
    for item in conn.execute("SELECT id, kicker, short_body FROM content_item"
                             " WHERE kind = 'feature'").fetchall():
        v2 = by_kicker.get(item["kicker"])
        if v2 is None:
            continue
        if not item["short_body"]:
            conn.execute("UPDATE content_item SET short_body = ? WHERE id = ?",
                         (v2["short_body"], item["id"]))
        has_specs = conn.execute("SELECT 1 FROM spec_row WHERE grp = 'feature_spec'"
                                 " AND item_id = ? LIMIT 1", (item["id"],)).fetchone()
        if not has_specs:
            _insert_rows(conn, "feature_spec", v2["specs"], item["id"])
    conn.execute("UPDATE apk_release SET release_notes = ?"
                 " WHERE version = '1.0.0' AND release_notes = ''", (V2_RELEASE_NOTES_1_0_0,))
    conn.execute("INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)",
                 (SEED_V2_MARKER, now_iso()))


def _split_install_steps(conn: sqlite3.Connection) -> None:
    """Étapes d'installation d'avant la colonne « précision » : celles qui ont
    encore exactement le texte par défaut sont découpées en titre + précision."""
    for row in conn.execute("SELECT id, label FROM spec_row WHERE grp = 'install'"
                            " AND value = ''").fetchall():
        split = INSTALL_SPLIT.get(row["label"])
        if split:
            conn.execute("UPDATE spec_row SET label = ?, value = ? WHERE id = ?",
                         (*split, row["id"]))


def init_db(db_path: Path, images_dir: Path) -> None:
    """Crée les tables et, au premier démarrage, le contenu initial.

    Un réglage ajouté plus tard à DEFAULT_SETTINGS est inséré dans les bases
    existantes sans écraser les valeurs déjà modifiées. Les contenus de la v2
    (fiche technique, comparatif, FAQ…) sont insérés une fois, s'ils manquent.
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
                for pos, f in enumerate(V2_FEATURES):
                    conn.execute(
                        "INSERT INTO content_item (kind, position, kicker, title, body, short_body)"
                        " VALUES ('feature', ?, ?, ?, ?, ?)",
                        (pos, f["kicker"], f["title"], f["body"], f["short_body"]))
                for pos, (title, body) in enumerate(V2_STEPS):
                    conn.execute(
                        "INSERT INTO content_item (kind, position, title, body)"
                        " VALUES ('step', ?, ?, ?)", (pos, title, body))
                for pos, (caption, description) in enumerate(V2_SCREENSHOTS):
                    conn.execute(
                        "INSERT INTO screenshot (filename, caption, description, position,"
                        " created_at) VALUES (NULL, ?, ?, ?, ?)",
                        (caption, description, pos, now_iso()))
            if SEED_V2_MARKER not in existing:
                _seed_v2(conn)
            _split_install_steps(conn)
            if first_run:
                # Base neuve : traductions du contenu initial. Une base existante
                # les reçoit avec python -m app.reseed_i18n (après simulation).
                for lang, tbl, row_id, field, _, translated in missing_translations(conn):
                    _write_translation(conn, lang, tbl, row_id, field, translated)
    finally:
        conn.close()


def get_db(db_path: Path) -> Iterator[sqlite3.Connection]:
    conn = connect(db_path)
    try:
        yield conn
    finally:
        conn.close()


# --- Lecture -----------------------------------------------------------------

def get_settings(conn: sqlite3.Connection, lang: str = "fr") -> dict[str, str]:
    """Réglages ; pour l'anglais ou l'espagnol, la traduction remplace le français
    quand elle existe (sinon le français reste : repli)."""
    site = {r["key"]: r["value"] for r in conn.execute("SELECT key, value FROM setting")
            if not r["key"].startswith("_")}
    if lang in TRANSLATION_LANGS:
        for (_, key), value in translations(conn, lang, "setting").items():
            if key in site and value.strip():
                site[key] = value
    return site


def translations(conn: sqlite3.Connection, lang: str, tbl: str) -> dict[tuple[int, str], str]:
    """Traductions d'une table : {(row_id, colonne): texte}."""
    if lang not in TRANSLATION_LANGS:
        return {}
    return {(r["row_id"], r["field"]): r["value"] for r in conn.execute(
        "SELECT row_id, field, value FROM translation WHERE lang = ? AND tbl = ?", (lang, tbl))}


def localize(conn: sqlite3.Connection, rows, tbl: str, lang: str) -> list[dict]:
    """Lignes d'une table, traduites quand une traduction existe (repli sur le français)."""
    out = [dict(r) for r in rows]
    found = translations(conn, lang, tbl)
    if found:
        for row in out:
            for field in TRANSLATABLE_COLUMNS[tbl]:
                value = found.get((row["id"], field))
                if value and value.strip():
                    row[field] = value
    return out


def _write_translation(conn: sqlite3.Connection, lang: str, tbl: str, row_id: int,
                       field: str, value: str) -> None:
    """Écrit (ou efface, si vide) une traduction ; à appeler dans une transaction."""
    if lang not in TRANSLATION_LANGS:
        raise ValueError(lang)
    if tbl == "setting":
        if field not in TRANSLATABLE_SETTINGS:
            raise KeyError(field)
    elif field not in TRANSLATABLE_COLUMNS.get(tbl, ()):
        raise KeyError(f"{tbl}.{field}")
    if (value or "").strip():
        conn.execute(
            "INSERT INTO translation (lang, tbl, row_id, field, value) VALUES (?, ?, ?, ?, ?)"
            " ON CONFLICT(lang, tbl, row_id, field) DO UPDATE SET value = excluded.value",
            (lang, tbl, row_id, field, value))
    else:
        conn.execute("DELETE FROM translation WHERE lang = ? AND tbl = ? AND row_id = ?"
                     " AND field = ?", (lang, tbl, row_id, field))


def set_translations(conn: sqlite3.Connection, lang: str,
                     values: list[tuple[str, int, str, str]]) -> None:
    """Enregistre des traductions [(tbl, row_id, colonne, texte)] ; texte vide = repli."""
    with conn:
        for tbl, row_id, field, value in values:
            _write_translation(conn, lang, tbl, row_id, field, value)


def set_setting_translations(conn: sqlite3.Connection, lang: str,
                             values: dict[str, str]) -> None:
    set_translations(conn, lang, [("setting", 0, key, value) for key, value in values.items()])


def translatable_texts(conn: sqlite3.Connection) -> list[tuple[str, int, str, str]]:
    """Tous les textes français traduisibles et non vides : [(tbl, row_id, colonne, français)]."""
    out = []
    site = get_settings(conn)
    for key in TRANSLATABLE_SETTINGS:
        if site.get(key, "").strip():
            out.append(("setting", 0, key, site[key]))
    for tbl, fields in TRANSLATABLE_COLUMNS.items():
        for row in conn.execute(f"SELECT id, {', '.join(fields)} FROM {tbl} ORDER BY id"):
            for field in fields:
                if (row[field] or "").strip():
                    out.append((tbl, row["id"], field, row[field]))
    return out


def translated_refs(conn: sqlite3.Connection, lang: str) -> set[tuple[str, int, str]]:
    """Textes qui ont une traduction dans cette langue : {(tbl, row_id, colonne)}."""
    if lang not in TRANSLATION_LANGS:
        return set()
    return {(r["tbl"], r["row_id"], r["field"]) for r in conn.execute(
        "SELECT tbl, row_id, field FROM translation WHERE lang = ?", (lang,))}


def missing_translations(conn: sqlite3.Connection) -> list[tuple[str, str, int, str, str, str]]:
    """Traductions connues (content_i18n) des textes français qui n'en ont pas encore :
    [(lang, tbl, row_id, colonne, français, traduction)]. Ne modifie rien."""
    out = []
    texts = translatable_texts(conn)
    for lang in TRANSLATION_LANGS:
        existing = translated_refs(conn, lang)
        for tbl, row_id, field, french in texts:
            if (tbl, row_id, field) in existing:
                continue
            translated = content_i18n.translate(french, lang)
            if translated:
                out.append((lang, tbl, row_id, field, french, translated))
    return out


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


def get_internal(conn: sqlite3.Connection, key: str) -> str | None:
    """Réglage interne (clé « _… »), jamais affiché ni modifiable comme un texte."""
    assert key.startswith("_")
    row = conn.execute("SELECT value FROM setting WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else None


def set_internal(conn: sqlite3.Connection, key: str, value: str) -> None:
    assert key.startswith("_")
    with conn:
        conn.execute("INSERT INTO setting (key, value) VALUES (?, ?)"
                     " ON CONFLICT(key) DO UPDATE SET value = excluded.value", (key, value))


def list_items(conn: sqlite3.Connection, kind: str) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM content_item WHERE kind = ? ORDER BY position, id", (kind,)
    ).fetchall()


def list_rows(conn: sqlite3.Connection, grp: str, item_id: int | None = None) -> list[sqlite3.Row]:
    if item_id is None:
        return conn.execute("SELECT * FROM spec_row WHERE grp = ? AND item_id IS NULL"
                            " ORDER BY position, id", (grp,)).fetchall()
    return conn.execute("SELECT * FROM spec_row WHERE grp = ? AND item_id = ?"
                        " ORDER BY position, id", (grp, item_id)).fetchall()


def rows_by_item(conn: sqlite3.Connection, grp: str) -> dict[int, list[sqlite3.Row]]:
    result: dict[int, list[sqlite3.Row]] = {}
    for row in conn.execute("SELECT * FROM spec_row WHERE grp = ? AND item_id IS NOT NULL"
                            " ORDER BY position, id", (grp,)):
        result.setdefault(row["item_id"], []).append(row)
    return result


def list_faq(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM faq ORDER BY position, id").fetchall()


def list_screenshots(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM screenshot ORDER BY position, id").fetchall()


def list_apks(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM apk_release ORDER BY uploaded_at DESC, id DESC").fetchall()


def current_apk(conn: sqlite3.Connection) -> sqlite3.Row | None:
    return conn.execute("SELECT * FROM apk_release WHERE is_current = 1").fetchone()


def list_messages(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute("SELECT * FROM contact_message ORDER BY created_at DESC, id DESC").fetchall()


def unread_count(conn: sqlite3.Connection) -> int:
    return int(conn.execute("SELECT COUNT(*) FROM contact_message WHERE is_read = 0").fetchone()[0])


def legal_missing(site: dict[str, str]) -> list[str]:
    """Libellés des champs obligatoires des mentions légales encore vides."""
    return [label for key, (label, required) in LEGAL_FIELDS.items()
            if required and not site.get(key, "").strip()]


# --- Ordre des listes ---------------------------------------------------------

ORDERED_TABLES = {"content_item", "screenshot", "spec_row", "faq"}


def next_position(conn: sqlite3.Connection, table: str, where: str = "1", args: tuple = ()) -> int:
    assert table in ORDERED_TABLES
    row = conn.execute(
        f"SELECT COALESCE(MAX(position), -1) + 1 AS p FROM {table} WHERE {where}", args
    ).fetchone()
    return int(row["p"])


def move(conn: sqlite3.Connection, table: str, row_id: int, direction: int,
         where: str = "1", args: tuple = ()) -> None:
    """Échange l'élément avec son voisin (direction -1 = monter, +1 = descendre)."""
    assert table in ORDERED_TABLES
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
