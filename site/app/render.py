"""Gabarits Jinja2 et filtres d'affichage."""

from __future__ import annotations

import hashlib
import re
from datetime import datetime, timezone
from pathlib import Path

from fastapi.templating import Jinja2Templates
from markupsafe import Markup, escape
from starlette.requests import Request

MONTHS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
          "août", "septembre", "octobre", "novembre", "décembre"]


def filesize(num: int) -> str:
    if num >= 1024 * 1024:
        return f"{num / (1024 * 1024):.1f} Mo".replace(".", ",")
    return f"{max(1, round(num / 1024))} Ko"


def date_fr(value: str) -> str:
    try:
        d = datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return value or ""
    return f"{d.day} {MONTHS[d.month - 1]} {d.year}"


MONTHS_SHORT = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.",
                "août", "sept.", "oct.", "nov.", "déc."]


def date_short(value: str) -> str:
    """« 9 oct. 2026 » (barre de navigation, notes de version)."""
    try:
        d = datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return value or ""
    return f"{d.day} {MONTHS_SHORT[d.month - 1]} {d.year}"


def when(value: str, mode: str = "list", now: datetime | None = None) -> str:
    """Date et heure d'un horodatage ISO (UTC), pour l'administration.

    mode « list » : « aujourd'hui, 9 h 12 », « hier, 21 h 40 », « 7 oct. »,
    « 7 oct. 2025 » ; mode « long » : « 7 octobre 2026, 18 h 05 ».
    Le serveur écrit l'heure UTC ; admin.js la remplace par l'heure locale.
    """
    try:
        d = datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return value or ""
    if d.tzinfo is not None:
        d = d.astimezone(timezone.utc).replace(tzinfo=None)
    now = now or datetime.now(timezone.utc).replace(tzinfo=None)
    hour = f"{d.hour} h {d.minute:02d} UTC"
    if mode == "long":
        return f"{d.day} {MONTHS[d.month - 1]} {d.year}, {hour}"
    days = (now.date() - d.date()).days
    if days == 0:
        return f"aujourd'hui, {hour}"
    if days == 1:
        return f"hier, {hour}"
    if d.year == now.year:
        return f"{d.day} {MONTHS_SHORT[d.month - 1]}"
    return f"{d.day} {MONTHS_SHORT[d.month - 1]} {d.year}"


# Espace avant ? ! : ; » et après « : rendue insécable, pour qu'un signe double ne
# commence jamais une ligne. U+00A0 plutôt que l'espace fine U+202F, absente
# d'Archivo (elle tomberait sur une police de repli).
_NBSP_BEFORE = re.compile(r"[  ](?=[?!:;»])")
_NBSP_AFTER = re.compile(r"(?<=«)[  ]")


def nbsp(text: str) -> str:
    """Espaces insécables de la typographie française (filtre `nbsp`)."""
    return _NBSP_AFTER.sub(" ", _NBSP_BEFORE.sub(" ", text or ""))


def _blocks(text: str, typo: bool = False) -> list[tuple[str, str]]:
    """Blocs du texte saisi : [(type, html)], type « h2 », « ul » ou « p »."""
    out: list[tuple[str, str]] = []
    for block in re.split(r"\n\s*\n", (text or "").replace("\r\n", "\n").strip()):
        lines = [line.strip() for line in block.split("\n") if line.strip()]
        if not lines:
            continue
        if typo:
            lines = [nbsp(line) for line in lines]
        if len(lines) == 1 and lines[0].startswith("## "):
            out.append(("h2", f"<h2>{escape(lines[0][3:].strip())}</h2>"))
        elif all(line.startswith("- ") for line in lines):
            items = "".join(f"<li>{escape(line[2:].strip())}</li>" for line in lines)
            out.append(("ul", f"<ul>{items}</ul>"))
        else:
            out.append(("p", "<p>" + "<br>".join(str(escape(line)) for line in lines) + "</p>"))
    return out


def rich_text(text: str, typo: bool = False) -> Markup:
    """Texte saisi dans l'administration -> HTML sûr.

    Paragraphes séparés par une ligne vide, « ## Titre » pour un intertitre,
    « - élément » pour une liste. Tout le texte est échappé. typo=True pose les
    espaces insécables (pages publiques ; pas pour les messages reçus).
    """
    return Markup("\n".join(html for _, html in _blocks(text, typo)))


def rich_sections(text: str) -> dict[str, Markup]:
    """Comme rich_text (avec les espaces insécables), découpé pour la mise en page :
    `intro` (ce qui précède le premier intertitre) et `body`, où chaque intertitre
    ouvre un <section class="policy__section"> qui court jusqu'au suivant."""
    intro: list[str] = []
    sections: list[list[str]] = []
    for kind, html in _blocks(text, typo=True):
        if kind == "h2":
            sections.append([html])
        elif sections:
            sections[-1].append(html)
        else:
            intro.append(html)
    body = "\n".join('<section class="policy__section">' + "\n".join(parts) + "</section>"
                     for parts in sections)
    return {"intro": Markup("\n".join(intro)), "body": Markup(body)}


def make_static_url(static_dir: Path):
    """Fonction `static_url("css/site.css")` des gabarits : « /static/css/site.css?v=<empreinte> ».

    L'empreinte (10 caractères du SHA-256 du fichier) est calculée une fois par
    fichier et par démarrage : une nouvelle version du fichier change l'URL, ce
    qui permettra un cache long côté Nginx. Les polices, appelées depuis les CSS,
    ne sont pas versionnées (le préchargement doit garder la même URL).
    """
    cache: dict[str, str] = {}

    def static_url(path: str) -> str:
        if path not in cache:
            file = static_dir / path
            cache[path] = (hashlib.sha256(file.read_bytes()).hexdigest()[:10]
                           if file.is_file() else "")
        version = cache[path]
        return f"/static/{path}?v={version}" if version else f"/static/{path}"

    return static_url


def make_templates(directory: Path, static_dir: Path | None = None,
                   site_url: str = "") -> Jinja2Templates:
    templates = Jinja2Templates(directory=str(directory))  # échappement HTML actif
    templates.env.globals["static_url"] = make_static_url(
        static_dir or directory.parent / "static")
    templates.env.globals["SITE_URL"] = site_url
    templates.env.filters["filesize"] = filesize
    templates.env.filters["date_fr"] = date_fr
    templates.env.filters["date_short"] = date_short
    templates.env.filters["rich_text"] = rich_text
    templates.env.filters["rich_sections"] = rich_sections
    templates.env.filters["nbsp"] = nbsp
    templates.env.filters["when"] = when
    return templates


def flash(request: Request, message: str, level: str = "ok") -> None:
    request.session.setdefault("flash", []).append([level, message])
    request.session["flash"] = request.session["flash"]


def page(request: Request, name: str, context: dict | None = None,
         status_code: int = 200, headers: dict | None = None):
    templates: Jinja2Templates = request.app.state.templates
    context = dict(context or {})
    if request.url.path.startswith("/admin") and "session" in request.scope:
        context.setdefault("flashes", request.session.pop("flash", []))
    return templates.TemplateResponse(
        request, name, context, status_code=status_code, headers=headers
    )
