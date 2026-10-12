"""Référencement : robots.txt, sitemap.xml, security.txt et données structurées
(JSON-LD) de l'accueil.

Toutes les URL absolues partent de `Settings.site_url` (réglage SITE_URL), jamais
de l'hôte de la requête.
"""

from __future__ import annotations

import re
from xml.sax.saxutils import escape, quoteattr

from . import i18n

# Titre et description de l'accueil (balises <title>, meta description, Open
# Graph et données structurées), dans chaque langue. Tout y est exact : jeu
# gratuit, sans publicité, Android, duel sur le même Wi-Fi sans Internet.
HOME_TITLE_SUFFIXES = {
    "fr": "le Pong qu'on joue en inclinant son téléphone (Android)",
    "en": "the Pong you play by tilting your phone (Android)",
    "es": "el Pong que se juega inclinando el teléfono (Android)",
}
HOME_DESCRIPTIONS = {
    "fr": "Jeu de Pong gratuit pour Android : penche ton téléphone pour bouger la raquette. "
          "Seul contre l'ordinateur ou à deux sur le même Wi-Fi, sans Internet ni pub.",
    "en": "Free Pong game for Android: tilt your phone to move the paddle. Play alone "
          "against the computer or with a friend on the same Wi-Fi, with no internet and no ads.",
    "es": "Juego de Pong gratis para Android: inclina el teléfono para mover la paleta. Solo "
          "contra la máquina o entre dos en el mismo Wi-Fi, sin internet ni anuncios.",
}
HOME_TITLE_SUFFIX = HOME_TITLE_SUFFIXES["fr"]
HOME_DESCRIPTION = HOME_DESCRIPTIONS["fr"]

# Image de partage (Open Graph, Twitter, JSON-LD), générée par tool/og_image.cjs.
OG_IMAGE = "img/og-tilto.png"
OG_IMAGE_WIDTH = 1200
OG_IMAGE_HEIGHT = 630

# Version d'Android minimale de l'application (minSdkVersion 21 = Android 5.0).
OPERATING_SYSTEMS = {"fr": "Android 5.0 ou plus", "en": "Android 5.0 or later",
                     "es": "Android 5.0 o superior"}
OPERATING_SYSTEM = OPERATING_SYSTEMS["fr"]

# Langues de l'application publiée (JSON-LD MobileApplication.inLanguage). L'APK
# 1.0.0 en ligne est en français ; passer à ["fr", "en", "es"] quand la 1.1.0
# (traduite) est proposée au téléchargement.
APP_LANGUAGES = ["fr"]

# Pages indexables, dans l'ordre du sitemap : page (i18n.PAGES) -> réglage donnant
# la date de dernière mise à jour (None : pas de date simple à donner).
SITEMAP_PAGES = [
    ("home", None),
    ("contact", None),
    ("privacy", "privacy_updated"),
    ("legal", "legal_updated"),
]

_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Robots d'entraînement des IA, refusés sur tout le site. Les robots de
# recherche des assistants ne sont pas listés : ils suivent la règle générale.
AI_TRAINING_BOTS = [
    "GPTBot", "ClaudeBot", "Google-Extended", "Applebot-Extended", "CCBot",
    "meta-externalagent", "Bytespider",
]


def robots_txt(site_url: str) -> str:
    """Politique « recherche oui, entraînement non ». /admin n'y figure pas
    (robots.txt est public) : ses pages portent <meta name="robots" content="noindex">.
    /api/ (lue par l'app) est exclue et absente du sitemap."""
    training = "\n".join(f"User-agent: {bot}" for bot in AI_TRAINING_BOTS)
    return (
        "# Robots de recherche des assistants (OAI-SearchBot, ChatGPT-User, PerplexityBot,\n"
        "# Perplexity-User, Claude-SearchBot, Claude-User) : autorisés comme tout le monde.\n"
        "\n"
        "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /telecharger\n"
        "Disallow: /contact/merci\n"
        "Disallow: /en/contact/thanks\n"
        "Disallow: /es/contacto/gracias\n"
        "Disallow: /sante\n"
        "Disallow: /api/\n"
        "\n"
        "# Robots d'entraînement des IA : refusés\n"
        f"{training}\n"
        "Disallow: /\n"
        "\n"
        f"Sitemap: {site_url}/sitemap.xml\n"
    )


def sitemap_xml(site_url: str, site: dict, apk: dict | None) -> str:
    """Pages publiques indexables, dans les trois langues ; chaque adresse liste ses
    versions dans les autres langues (xhtml:link hreflang, x-default = français).
    lastmod : date de l'APK courant pour l'accueil, dates de mise à jour saisies
    pour la confidentialité et les mentions légales (communes aux trois langues)."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'
             ' xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for page, date_key in SITEMAP_PAGES:
        if page == "home":
            lastmod = apk["date"] if apk else ""
        else:
            lastmod = site.get(date_key, "") if date_key else ""
        lastmod = lastmod.strip() if _DATE.match(lastmod.strip() or "") else ""
        links = "".join(
            f'<xhtml:link rel="alternate" hreflang="{alt["hreflang"]}"'
            f' href={quoteattr(alt["href"])}/>' for alt in i18n.alternates(page, site_url))
        for lang in i18n.LANGS:
            entry = f"  <url><loc>{escape(site_url + i18n.path(page, lang))}</loc>"
            if lastmod:
                entry += f"<lastmod>{lastmod}</lastmod>"
            lines.append(entry + links + "</url>")
    lines.append("</urlset>")
    return "\n".join(lines) + "\n"


def security_txt(site_url: str) -> str:
    """RFC 9116."""
    return (
        f"Contact: {site_url}/contact\n"
        "Expires: 2027-10-01T00:00:00.000Z\n"
        "Preferred-Languages: fr, en, es\n"
        f"Canonical: {site_url}/.well-known/security.txt\n"
    )


def home_json_ld(site_url: str, context: dict, lang: str = "fr") -> dict:
    """Graphe schema.org de l'accueil : WebSite, Organization (studio),
    MobileApplication et, s'il y a des questions, FAQPage (texte exact de la base).

    Jamais de note ni d'avis : le site n'en publie pas. Version et lien de
    téléchargement seulement si un APK est en ligne ; captures seulement celles
    qui ont une image."""
    site = context["site"]
    apk = context.get("apk")
    root = site_url + "/"
    home = site_url + i18n.path("home", lang)
    name = site.get("game_name") or "Tilto"
    # Le studio est le même dans les trois langues : un seul identifiant.
    org_id = root + "#studio"

    organization = {"@type": "Organization", "@id": org_id,
                    "name": site.get("studio_name") or "Nexora", "url": root}
    if site.get("studio_logo_url"):
        organization["logo"] = site_url + site["studio_logo_url"]

    website = {"@type": "WebSite", "@id": home + "#site", "url": home, "name": name,
               "inLanguage": lang, "publisher": {"@id": org_id}}

    application = {
        "@type": "MobileApplication",
        "@id": home + "#application",
        "name": name,
        "description": HOME_DESCRIPTIONS[lang],
        "url": home,
        "operatingSystem": OPERATING_SYSTEMS[lang],
        "applicationCategory": "GameApplication",
        "genre": "Arcade",
        "inLanguage": APP_LANGUAGES[0] if len(APP_LANGUAGES) == 1 else APP_LANGUAGES,
        "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR"},
        "author": {"@id": org_id},
        "publisher": {"@id": org_id},
        "image": f"{site_url}/static/{OG_IMAGE}",
    }
    if apk:
        application["softwareVersion"] = apk["version"]
        application["downloadUrl"] = site_url + "/telecharger"
    shots = [f"{site_url}/media/{s['filename']}"
             for s in context.get("screenshots") or [] if s["filename"]]
    if shots:
        application["screenshot"] = shots

    graph = [website, organization, application]
    faq = context.get("faq") or []
    if faq:
        graph.append({
            "@type": "FAQPage",
            "@id": home + "#faq",
            "inLanguage": lang,
            "mainEntity": [
                {"@type": "Question", "name": q["question"],
                 "acceptedAnswer": {"@type": "Answer", "text": q["answer"]}}
                for q in faq if q["question"] and q["answer"]
            ],
        })
    return {"@context": "https://schema.org", "@graph": graph}
