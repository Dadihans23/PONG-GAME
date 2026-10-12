"""Langues du site : français à la racine, anglais sous /en/, espagnol sous /es/.

Ce module ne contient que les textes FIXES de l'interface (lien d'évitement,
libellés du formulaire, pages d'erreur, boutons…) et les adresses des pages dans
chaque langue. Les textes modifiables dans l'administration sont en base, avec
une valeur par langue (repli sur le français : voir db.get_settings / db.localize).

Aucune redirection selon la langue du navigateur : chaque page existe à une seule
adresse par langue, et un bandeau (static/js/lang.js) propose seulement la langue
du navigateur quand elle diffère de celle de la page.
"""

from __future__ import annotations

LANGS = ("fr", "en", "es")
DEFAULT_LANG = "fr"

# Nom de chaque langue, écrit dans sa langue (jamais traduit), pour le sélecteur.
NATIVE_NAMES = {"fr": "Français", "en": "English", "es": "Español"}
# <html lang>, Open Graph.
HTML_LANG = {"fr": "fr", "en": "en", "es": "es"}
OG_LOCALE = {"fr": "fr_FR", "en": "en_US", "es": "es_ES"}

# Adresse canonique de chaque page dans chaque langue. Slugs traduits : une
# adresse lisible dans la langue du visiteur (« /es/privacidad »), comme le
# reste de la page. Les anciennes adresses françaises restent inchangées.
PAGES: dict[str, dict[str, str]] = {
    "home": {"fr": "/", "en": "/en/", "es": "/es/"},
    "contact": {"fr": "/contact", "en": "/en/contact", "es": "/es/contacto"},
    "privacy": {"fr": "/confidentialite", "en": "/en/privacy", "es": "/es/privacidad"},
    "legal": {"fr": "/mentions-legales", "en": "/en/legal-notice", "es": "/es/aviso-legal"},
    "contact_sent": {"fr": "/contact/merci", "en": "/en/contact/thanks",
                     "es": "/es/contacto/gracias"},
}
# Pages indexables (sitemap, hreflang), dans l'ordre du sitemap.
INDEXABLE = ("home", "contact", "privacy", "legal")

PREFIXES = {"en": "/en", "es": "/es"}


def path(page: str, lang: str) -> str:
    return PAGES[page][lang if lang in LANGS else DEFAULT_LANG]


def lang_of_path(url_path: str) -> str:
    """Langue d'une adresse d'après son préfixe (/en, /es) ; français sinon."""
    for lang, prefix in PREFIXES.items():
        if url_path == prefix or url_path.startswith(prefix + "/"):
            return lang
    return DEFAULT_LANG


def page_of_path(url_path: str) -> str | None:
    for page, paths in PAGES.items():
        if url_path in paths.values():
            return page
    return None


def redirects() -> dict[str, str]:
    """Variantes d'adresse -> adresse canonique (redirection 301).

    - /en et /es sans « / » final ; /fr, /fr/ et /fr/<page> vers la racine ;
    - une page demandée avec un « / » final ;
    - le slug d'une autre langue : sous un préfixe, la page dans la langue du préfixe
      (/en/confidentialite -> /en/privacy) ; sans préfixe, en français, la langue de
      la racine (/privacy -> /confidentialite).
    Une adresse canonique n'est jamais une variante.
    """
    canonical = {p for paths in PAGES.values() for p in paths.values()}
    out: dict[str, str] = {"/en": "/en/", "/es": "/es/", "/fr": "/", "/fr/": "/"}
    for paths in PAGES.values():
        for target in paths.values():
            if not target.endswith("/"):
                out[target + "/"] = target
        slugs = {_slug(p) for p in paths.values()} - {""}
        for slug in slugs:
            for lang in LANGS:
                out.setdefault(f"{PREFIXES.get(lang, '')}/{slug}", paths[lang])
            out.setdefault(f"/fr/{slug}", paths["fr"])
    return {k: v for k, v in out.items() if k not in canonical}


def _slug(page_path: str) -> str:
    for prefix in PREFIXES.values():
        if page_path.startswith(prefix + "/"):
            return page_path[len(prefix) + 1:]
    return page_path.lstrip("/")


def alternates(page: str, site_url: str) -> list[dict]:
    """<link rel="alternate" hreflang> : les trois langues, puis x-default (français)."""
    links = [{"hreflang": lang, "href": site_url + PAGES[page][lang]} for lang in LANGS]
    links.append({"hreflang": "x-default", "href": site_url + PAGES[page][DEFAULT_LANG]})
    return links


def language_links(page: str | None, lang: str) -> list[dict]:
    """Sélecteur FR · EN · ES : la même page dans chaque langue (l'accueil si la page
    n'a pas d'équivalent, par exemple une page d'erreur)."""
    target = page if page in PAGES else "home"
    return [{"code": code, "label": code.upper(), "name": NATIVE_NAMES[code],
             "href": PAGES[target][code], "current": code == lang} for code in LANGS]


# --- Textes fixes de l'interface ---------------------------------------------------
# Une clé par texte ; {x} = valeur insérée par le gabarit (.format). Toute nouvelle
# clé s'écrit dans les trois langues (test_i18n vérifie qu'aucune ne manque).

UI: dict[str, dict[str, str]] = {
    # En-tête, menus, pied de page (base.html)
    "skip": {"fr": "Aller au contenu", "en": "Skip to content", "es": "Ir al contenido"},
    "home_aria": {"fr": "{game}, accueil", "en": "{game}, home", "es": "{game}, inicio"},
    "by_studio": {"fr": "un jeu de {studio}", "en": "a game by {studio}",
                  "es": "un juego de {studio}"},
    "news": {"fr": "Nouveautés {version}", "en": "What's new in {version}",
             "es": "Novedades {version}"},
    "contact": {"fr": "Contact", "en": "Contact", "es": "Contacto"},
    "main_nav": {"fr": "Navigation principale", "en": "Main navigation",
                 "es": "Navegación principal"},
    "nav_game": {"fr": "Le jeu", "en": "The game", "es": "El juego"},
    "nav_modes": {"fr": "Solo ou Duel", "en": "Solo or Duel", "es": "Solo o Duelo"},
    "nav_play": {"fr": "Comment jouer", "en": "How to play", "es": "Cómo jugar"},
    "nav_shots": {"fr": "Captures", "en": "Screenshots", "es": "Capturas"},
    "nav_faq": {"fr": "FAQ", "en": "FAQ", "es": "Preguntas"},
    "lang_aria": {"fr": "Langue", "en": "Language", "es": "Idioma"},
    "theme_aria": {"fr": "Changer de thème", "en": "Change theme", "es": "Cambiar de tema"},
    "theme_to_light": {"fr": "Passer en mode clair", "en": "Switch to light mode",
                       "es": "Cambiar a modo claro"},
    "theme_to_dark": {"fr": "Passer en mode sombre", "en": "Switch to dark mode",
                      "es": "Cambiar a modo oscuro"},
    "download": {"fr": "Télécharger", "en": "Download", "es": "Descargar"},
    "menu": {"fr": "Menu", "en": "Menu", "es": "Menú"},
    "menu_close": {"fr": "Fermer le menu", "en": "Close menu", "es": "Cerrar el menú"},
    "footer_aria": {"fr": "Pied de page", "en": "Footer", "es": "Pie de página"},
    "privacy": {"fr": "Politique de confidentialité", "en": "Privacy policy",
                "es": "Política de privacidad"},
    "legal": {"fr": "Mentions légales", "en": "Legal notice", "es": "Aviso legal"},
    "credit": {"fr": "Un jeu de {studio} · © {year}", "en": "A game by {studio} · © {year}",
               "es": "Un juego de {studio} · © {year}"},
    "to_top": {"fr": "Revenir en haut de la page", "en": "Back to top of page",
               "es": "Volver al principio de la página"},
    "og_alt": {
        "fr": "{game}, le Pong qu'on joue en inclinant son téléphone : terrain vertical, "
              "raquette bleue en bas, balle blanche, raquette verte en haut.",
        "en": "{game}, the Pong you play by tilting your phone: vertical court, blue paddle "
              "at the bottom, white ball, green paddle at the top.",
        "es": "{game}, el Pong que se juega inclinando el teléfono: campo vertical, paleta "
              "azul abajo, pelota blanca, paleta verde arriba.",
    },
    # Bandeau de suggestion de langue (lang.js) : écrit dans la langue proposée.
    "suggest_text": {"fr": "Ce site existe aussi en français.",
                     "en": "This site is also available in English.",
                     "es": "Este sitio también está disponible en español."},
    "suggest_link": {"fr": "Lire cette page en français", "en": "Read this page in English",
                     "es": "Leer esta página en español"},
    "suggest_close": {"fr": "Fermer", "en": "Close", "es": "Cerrar"},
    "suggest_aria": {"fr": "Langue du site", "en": "Site language", "es": "Idioma del sitio"},
    # Pages d'erreur
    "error_kicker": {"fr": "Erreur {status}", "en": "Error {status}", "es": "Error {status}"},
    "err_403": {"fr": "Action refusée. Rechargez la page et réessayez.",
                "en": "Action refused. Reload the page and try again.",
                "es": "Acción rechazada. Recarga la página e inténtalo de nuevo."},
    "err_404": {"fr": "Cette page n'existe pas.", "en": "This page doesn't exist.",
                "es": "Esta página no existe."},
    "err_405": {"fr": "Méthode non autorisée.", "en": "Method not allowed.",
                "es": "Método no permitido."},
    "err_429": {"fr": "Trop de tentatives. Réessayez plus tard.",
                "en": "Too many attempts. Try again later.",
                "es": "Demasiados intentos. Inténtalo más tarde."},
    "err_other": {"fr": "Erreur.", "en": "Error.", "es": "Error."},
    "err_no_apk": {"fr": "Aucune version de l'application n'est disponible pour le moment.",
                   "en": "No version of the app is available yet.",
                   "es": "Todavía no hay ninguna versión de la app disponible."},
    "back_home": {"fr": "Retour à l'accueil", "en": "Back to home", "es": "Volver al inicio"},
    # Pages légales
    "updated": {"fr": "Dernière mise à jour : {date}", "en": "Last updated: {date}",
                "es": "Última actualización: {date}"},
    "official_note": {
        "fr": "",
        "en": "This is a translation. If it differs from the French version, the French "
              "version prevails.",
        "es": "Esta es una traducción. Si difiere de la versión en francés, prevalece la "
              "versión en francés.",
    },
    "official_link": {"fr": "", "en": "Read the French version",
                      "es": "Leer la versión en francés"},
    "privacy_title": {"fr": "Politique de confidentialité · {game}",
                      "en": "Privacy policy · {game}", "es": "Política de privacidad · {game}"},
    "privacy_desc": {
        "fr": "{game} ne collecte aucune donnée personnelle : pas de compte, pas de pub, pas "
              "de mesure d'audience. Ce que le jeu garde sur ton téléphone, et rien d'autre.",
        "en": "{game} collects no personal data: no account, no ads, no analytics. What the "
              "game keeps on your phone, and nothing else.",
        "es": "{game} no recopila ningún dato personal: sin cuenta, sin anuncios, sin medición "
              "de audiencia. Lo que el juego guarda en tu teléfono, y nada más.",
    },
    "legal_title": {"fr": "Mentions légales · {game}", "en": "Legal notice · {game}",
                    "es": "Aviso legal · {game}"},
    "legal_desc": {
        "fr": "Mentions légales du site de {game}, le jeu de Pong gratuit pour Android du "
              "studio {studio} : éditeur du site, directeur de la publication et hébergeur.",
        "en": "Legal notice for the website of {game}, the free Pong game for Android by the "
              "{studio} studio: site publisher, publication director and hosting provider.",
        "es": "Aviso legal del sitio de {game}, el juego de Pong gratis para Android del "
              "estudio {studio}: editor del sitio, director de la publicación y proveedor de "
              "alojamiento.",
    },
    "legal_publisher": {"fr": "Éditeur du site", "en": "Site publisher", "es": "Editor del sitio"},
    "legal_director": {"fr": "Directeur de la publication", "en": "Publication director",
                       "es": "Director de la publicación"},
    "legal_host": {"fr": "Hébergeur", "en": "Hosting provider",
                   "es": "Proveedor de alojamiento"},
    "legal_l_name_company": {"fr": "Nom ou raison sociale", "en": "Name or company name",
                             "es": "Nombre o razón social"},
    "legal_l_form": {"fr": "Forme juridique", "en": "Legal form", "es": "Forma jurídica"},
    "legal_l_registration": {"fr": "Immatriculation", "en": "Registration number",
                             "es": "Número de registro"},
    "legal_l_address": {"fr": "Adresse", "en": "Address", "es": "Dirección"},
    "legal_l_email": {"fr": "E-mail", "en": "Email", "es": "Correo electrónico"},
    "legal_l_phone": {"fr": "Téléphone", "en": "Phone", "es": "Teléfono"},
    "legal_l_name": {"fr": "Nom", "en": "Name", "es": "Nombre"},
    "legal_contact_before": {"fr": "Pour toute question, utilise le ",
                             "en": "For any question, use the ",
                             "es": "Si tienes alguna pregunta, usa el "},
    "legal_contact_link": {"fr": "formulaire de contact", "en": "contact form",
                           "es": "formulario de contacto"},
    "legal_contact_after": {"fr": ".", "en": ".", "es": "."},
    # Contact
    "contact_title": {"fr": "Contact · {game}", "en": "Contact · {game}",
                      "es": "Contacto · {game}"},
    "contact_desc": {
        "fr": "Une question, un souci ou une idée sur {game}, le Pong qu'on joue en inclinant "
              "son téléphone ? Écris à l'équipe de {studio} : on te répond par e-mail.",
        "en": "A question, a problem or an idea about {game}, the Pong you play by tilting "
              "your phone? Write to the {studio} team: we'll reply by email.",
        "es": "¿Una pregunta, un problema o una idea sobre {game}, el Pong que se juega "
              "inclinando el teléfono? Escribe al equipo de {studio}: te responderemos por "
              "correo electrónico.",
    },
    "contact_lead": {"fr": "Une question, un problème, une idée ? Écris-nous : on te répond par",
                     "en": "A question, a problem, an idea? Write to us and we'll reply by",
                     "es": "¿Una pregunta, un problema, una idea? Escríbenos y te responderemos por"},
    "contact_lead_end": {"fr": "e-mail", "en": "email", "es": "correo"},
    "contact_faq_before": {"fr": "Avant d'écrire, jette un œil aux ",
                           "en": "Before writing, have a look at the ",
                           "es": "Antes de escribir, echa un vistazo a las "},
    "contact_faq_link": {"fr": "questions fréquentes", "en": "frequently asked questions",
                         "es": "preguntas frecuentes"},
    "contact_direct": {"fr": "Tu peux aussi écrire directement à ",
                       "en": "You can also write directly to ",
                       "es": "También puedes escribir directamente a "},
    "errors_one": {"fr": "Un champ est à corriger :", "en": "One field needs fixing:",
                   "es": "Hay un campo que corregir:"},
    "errors_many": {"fr": "{n} champs sont à corriger :", "en": "{n} fields need fixing:",
                    "es": "Hay {n} campos que corregir:"},
    "f_name": {"fr": "Ton nom", "en": "Your name", "es": "Tu nombre"},
    "optional": {"fr": "(facultatif)", "en": "(optional)", "es": "(opcional)"},
    "f_email": {"fr": "Ton adresse e-mail", "en": "Your email address",
                "es": "Tu correo electrónico"},
    "f_subject": {"fr": "Sujet", "en": "Subject", "es": "Asunto"},
    "f_message": {"fr": "Message", "en": "Message", "es": "Mensaje"},
    "count_static": {"fr": "{max} caractères au maximum.", "en": "{max} characters maximum.",
                     "es": "{max} caracteres como máximo."},
    # Compteur en direct (contact.js) : {used}, {max}, {left}.
    "count_live": {"fr": "{used} / {max} caractères", "en": "{used} / {max} characters",
                   "es": "{used} / {max} caracteres"},
    "count_full": {"fr": " : limite atteinte.", "en": ": limit reached.",
                   "es": ": límite alcanzado."},
    "count_left": {"fr": " : encore {left}.", "en": ": {left} left.", "es": ": quedan {left}."},
    "honeypot": {"fr": "Ne pas remplir ce champ", "en": "Leave this field empty",
                 "es": "No rellenes este campo"},
    "send": {"fr": "Envoyer le message", "en": "Send message", "es": "Enviar mensaje"},
    "contact_note_before": {
        "fr": "Ton adresse et ton message servent uniquement à te répondre. Voir la ",
        "en": "Your address and your message are only used to reply to you. See the ",
        "es": "Tu dirección y tu mensaje solo sirven para responderte. Consulta la ",
    },
    "contact_note_after": {"fr": ".", "en": ".", "es": "."},
    "subject_Question": {"fr": "Question", "en": "Question", "es": "Pregunta"},
    "subject_Problème technique": {"fr": "Problème technique", "en": "Technical problem",
                                   "es": "Problema técnico"},
    "subject_Suggestion": {"fr": "Suggestion", "en": "Suggestion", "es": "Sugerencia"},
    "subject_Autre": {"fr": "Autre", "en": "Other", "es": "Otro"},
    "err_token": {
        "fr": "Le formulaire a expiré ou n'est plus valide. Vérifie ton message et renvoie-le.",
        "en": "The form has expired or is no longer valid. Check your message and send it again.",
        "es": "El formulario caducó o ya no es válido. Revisa tu mensaje y vuelve a enviarlo.",
    },
    "err_fast": {
        "fr": "Le formulaire a été envoyé trop vite. Attends quelques secondes, puis renvoie-le.",
        "en": "The form was sent too quickly. Wait a few seconds, then send it again.",
        "es": "El formulario se envió demasiado rápido. Espera unos segundos y vuelve a enviarlo.",
    },
    "err_rate": {
        "fr": "Trop de messages envoyés depuis cette connexion. Réessaie dans une heure.",
        "en": "Too many messages sent from this connection. Try again in an hour.",
        "es": "Se enviaron demasiados mensajes desde esta conexión. Inténtalo de nuevo dentro "
              "de una hora.",
    },
    "err_email_missing": {
        "fr": "Indique ton adresse e-mail, pour qu'on puisse te répondre.",
        "en": "Enter your email address so we can reply to you.",
        "es": "Escribe tu correo electrónico para que podamos responderte.",
    },
    "err_email_invalid": {"fr": "L'adresse e-mail n'est pas valide.",
                          "en": "This email address isn't valid.",
                          "es": "El correo electrónico no es válido."},
    "err_subject": {"fr": "Choisis un sujet dans la liste.", "en": "Choose a subject from the list.",
                    "es": "Elige un asunto de la lista."},
    "err_message_missing": {"fr": "Écris ton message.", "en": "Write your message.",
                            "es": "Escribe tu mensaje."},
    "err_message_long": {
        "fr": "Ton message est trop long ({n} caractères, {max} au maximum).",
        "en": "Your message is too long ({n} characters, {max} maximum).",
        "es": "Tu mensaje es demasiado largo ({n} caracteres, {max} como máximo).",
    },
    # Message envoyé
    "sent_title": {"fr": "Message envoyé · {game}", "en": "Message sent · {game}",
                   "es": "Mensaje enviado · {game}"},
    "sent_h1": {"fr": "Message envoyé", "en": "Message sent", "es": "Mensaje enviado"},
    "sent_thanks": {"fr": "Merci ! Ton message est bien arrivé.",
                    "en": "Thank you! Your message has arrived.",
                    "es": "¡Gracias! Tu mensaje llegó bien."},
    "sent_reply": {"fr": "On te répondra à l'adresse e-mail que tu as indiquée.",
                   "en": "We'll reply to the email address you gave.",
                   "es": "Te responderemos al correo electrónico que indicaste."},
    "faq_button": {"fr": "Questions fréquentes", "en": "Frequently asked questions",
                   "es": "Preguntas frecuentes"},
    # Accueil (index.html). Titre : « Tilto : le Pong… » (espace avant « : » en français).
    "home_title": {"fr": "{game} : {suffix}", "en": "{game}: {suffix}", "es": "{game}: {suffix}"},
    "gp_download": {"fr": "Télécharger sur Google Play", "en": "Download on Google Play",
                    "es": "Descargar en Google Play"},
    "apk_download": {"fr": "Télécharger l'APK", "en": "Download the APK",
                     "es": "Descargar el APK"},
    "google_play": {"fr": "Google Play", "en": "Google Play", "es": "Google Play"},
    "no_play_store": {"fr": "sans Play Store", "en": "no Play Store needed",
                      "es": "sin Play Store"},
    "scr_speed": {"fr": "VITESSE 3", "en": "SPEED 3", "es": "VELOCIDAD 3"},
    "scr_record": {"fr": "RECORD {score}", "en": "BEST {score}", "es": "RÉCORD {score}"},
    "scr_duel": {"fr": "DUEL · PREMIER À 5", "en": "DUEL · FIRST TO 5", "es": "DUELO · A 5 PUNTOS"},
    "sense_low": {"fr": "Douce", "en": "Low", "es": "Baja"},
    "sense_high": {"fr": "Vive", "en": "High", "es": "Alta"},
    "records_label": {"fr": "TON RECORD", "en": "YOUR HIGH SCORE", "es": "TU RÉCORD"},
    "court_them": {"fr": "ORDINATEUR", "en": "COMPUTER", "es": "MÁQUINA"},
    "court_me": {"fr": "TOI", "en": "YOU", "es": "TÚ"},
    "court_demo": {"fr": "DÉMO", "en": "DEMO", "es": "DEMO"},
    "court_demo_mode": {"fr": " · SOLO NORMAL", "en": " · SOLO NORMAL", "es": " · SOLO NORMAL"},
    "vs": {"fr": "VS", "en": "VS", "es": "VS"},
    "t_features": {"fr": "Le jeu", "en": "The game", "es": "El juego"},
    "t_compare": {"fr": "Solo ou Duel", "en": "Solo or Duel", "es": "Solo o Duelo"},
    "t_steps": {"fr": "Comment jouer", "en": "How to play", "es": "Cómo jugar"},
    "t_scoring": {"fr": "Barème", "en": "Scoring", "es": "Puntuación"},
    "t_screens": {"fr": "Captures", "en": "Screenshots", "es": "Capturas"},
    "t_faq": {"fr": "Questions fréquentes", "en": "Frequently asked questions",
              "es": "Preguntas frecuentes"},
    "t_download": {"fr": "Télécharge {game}", "en": "Download {game}", "es": "Descarga {game}"},
    "t_install": {"fr": "Installer l'APK", "en": "Install the APK", "es": "Instalar el APK"},
    "t_notes": {"fr": "Nouveautés", "en": "What's new", "es": "Novedades"},
    "compare_caption": {"fr": "Comparatif des modes Solo et Duel",
                        "en": "Comparison of the Solo and Duel modes",
                        "es": "Comparación de los modos Solo y Duelo"},
    "col_solo": {"fr": "Solo", "en": "Solo", "es": "Solo"},
    "col_duel": {"fr": "Duel", "en": "Duel", "es": "Duelo"},
    "shot_alt": {"fr": "Capture de {game}", "en": "{game} screenshot", "es": "Captura de {game}"},
    "shots_aria": {"fr": "Captures d'écran", "en": "Screenshots", "es": "Capturas de pantalla"},
    "sha_more": {"fr": "Empreinte complète", "en": "Full checksum", "es": "Huella completa"},
    "sha_file": {"fr": "Fichier : {name}", "en": "File: {name}", "es": "Archivo: {name}"},
}

# Sujets du formulaire de contact : valeur enregistrée (en français, lue dans
# l'administration) -> clé du libellé affiché.
SUBJECT_KEYS = ("Question", "Problème technique", "Suggestion", "Autre")


class Catalog:
    """Textes d'une langue pour les gabarits : `t.skip`, `t("credit", studio=…, year=…)`."""

    def __init__(self, lang: str):
        self.lang = lang if lang in LANGS else DEFAULT_LANG

    def __getattr__(self, key: str) -> str:
        try:
            return UI[key][self.lang]
        except KeyError:
            raise AttributeError(key) from None

    def __call__(self, key: str, **values) -> str:
        text = UI[key][self.lang]
        return text.format(**values) if values else text

    def subject(self, value: str) -> str:
        return UI.get(f"subject_{value}", {}).get(self.lang, value)


def catalog(lang: str) -> Catalog:
    return Catalog(lang)


def ui(key: str, lang: str, **values) -> str:
    return Catalog(lang)(key, **values)
