"""Référencement : robots.txt, sitemap.xml, security.txt et données structurées
(JSON-LD) de l'accueil.

Toutes les URL absolues partent de `Settings.site_url` (réglage SITE_URL), jamais
de l'hôte de la requête.
"""

from __future__ import annotations

import re
from xml.sax.saxutils import escape

# Titre et description de l'accueil (balises <title>, meta description, Open
# Graph et données structurées). Tout y est exact : jeu gratuit, sans publicité,
# Android, duel sur le même Wi-Fi sans Internet.
HOME_TITLE_SUFFIX = "le Pong qu'on joue en inclinant son téléphone (Android)"
HOME_DESCRIPTION = (
    "Jeu de Pong gratuit pour Android : penche ton téléphone pour bouger la raquette. "
    "Seul contre l'ordinateur ou à deux sur le même Wi-Fi, sans Internet ni pub."
)

# Image de partage (Open Graph, Twitter, JSON-LD), générée par tool/og_image.cjs.
OG_IMAGE = "img/og-tilto.png"
OG_IMAGE_WIDTH = 1200
OG_IMAGE_HEIGHT = 630

# Version d'Android minimale de l'application (minSdkVersion 21 = Android 5.0).
OPERATING_SYSTEM = "Android 5.0 ou plus"

# Pages indexables, dans l'ordre du sitemap : chemin -> réglage donnant la date
# de dernière mise à jour (None : pas de date simple à donner).
SITEMAP_PAGES = [
    ("/", None),
    ("/contact", None),
    ("/confidentialite", "privacy_updated"),
    ("/mentions-legales", "legal_updated"),
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
    (robots.txt est public) : ses pages portent <meta name="robots" content="noindex">."""
    training = "\n".join(f"User-agent: {bot}" for bot in AI_TRAINING_BOTS)
    return (
        "# Robots de recherche des assistants (OAI-SearchBot, ChatGPT-User, PerplexityBot,\n"
        "# Perplexity-User, Claude-SearchBot, Claude-User) : autorisés comme tout le monde.\n"
        "\n"
        "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /telecharger\n"
        "Disallow: /contact/merci\n"
        "Disallow: /sante\n"
        "\n"
        "# Robots d'entraînement des IA : refusés\n"
        f"{training}\n"
        "Disallow: /\n"
        "\n"
        f"Sitemap: {site_url}/sitemap.xml\n"
    )


def sitemap_xml(site_url: str, site: dict, apk: dict | None) -> str:
    """Pages publiques indexables. lastmod : date de l'APK courant pour l'accueil,
    dates de mise à jour saisies pour la confidentialité et les mentions légales."""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for path, date_key in SITEMAP_PAGES:
        if path == "/":
            lastmod = apk["date"] if apk else ""
        else:
            lastmod = site.get(date_key, "") if date_key else ""
        lastmod = lastmod.strip() if _DATE.match(lastmod.strip() or "") else ""
        entry = f"  <url><loc>{escape(site_url + path)}</loc>"
        if lastmod:
            entry += f"<lastmod>{lastmod}</lastmod>"
        lines.append(entry + "</url>")
    lines.append("</urlset>")
    return "\n".join(lines) + "\n"


def security_txt(site_url: str) -> str:
    """RFC 9116."""
    return (
        f"Contact: {site_url}/contact\n"
        "Expires: 2027-10-01T00:00:00.000Z\n"
        "Preferred-Languages: fr, en\n"
        f"Canonical: {site_url}/.well-known/security.txt\n"
    )


def home_json_ld(site_url: str, context: dict) -> dict:
    """Graphe schema.org de l'accueil : WebSite, Organization (studio),
    MobileApplication et, s'il y a des questions, FAQPage (texte exact de la base).

    Jamais de note ni d'avis : le site n'en publie pas. Version et lien de
    téléchargement seulement si un APK est en ligne ; captures seulement celles
    qui ont une image."""
    site = context["site"]
    apk = context.get("apk")
    home = site_url + "/"
    name = site.get("game_name") or "Tilto"
    org_id = home + "#studio"

    organization = {"@type": "Organization", "@id": org_id,
                    "name": site.get("studio_name") or "Nexora", "url": home}
    if site.get("studio_logo_url"):
        organization["logo"] = site_url + site["studio_logo_url"]

    website = {"@type": "WebSite", "@id": home + "#site", "url": home, "name": name,
               "inLanguage": "fr", "publisher": {"@id": org_id}}

    application = {
        "@type": "MobileApplication",
        "@id": home + "#application",
        "name": name,
        "description": HOME_DESCRIPTION,
        "url": home,
        "operatingSystem": OPERATING_SYSTEM,
        "applicationCategory": "GameApplication",
        "genre": "Arcade",
        "inLanguage": "fr",
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
            "mainEntity": [
                {"@type": "Question", "name": q["question"],
                 "acceptedAnswer": {"@type": "Answer", "text": q["answer"]}}
                for q in faq if q["question"] and q["answer"]
            ],
        })
    return {"@context": "https://schema.org", "@graph": graph}
