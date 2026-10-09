"""Gabarits Jinja2 et filtres d'affichage."""

from __future__ import annotations

import re
from datetime import datetime
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


def rich_text(text: str) -> Markup:
    """Texte saisi dans l'administration -> HTML sûr.

    Paragraphes séparés par une ligne vide, « ## Titre » pour un intertitre,
    « - élément » pour une liste. Tout le texte est échappé.
    """
    html: list[str] = []
    for block in re.split(r"\n\s*\n", (text or "").replace("\r\n", "\n").strip()):
        lines = [line.strip() for line in block.split("\n") if line.strip()]
        if not lines:
            continue
        if len(lines) == 1 and lines[0].startswith("## "):
            html.append(f"<h2>{escape(lines[0][3:].strip())}</h2>")
        elif all(line.startswith("- ") for line in lines):
            items = "".join(f"<li>{escape(line[2:].strip())}</li>" for line in lines)
            html.append(f"<ul>{items}</ul>")
        else:
            html.append("<p>" + "<br>".join(str(escape(line)) for line in lines) + "</p>")
    return Markup("\n".join(html))


def make_templates(directory: Path) -> Jinja2Templates:
    templates = Jinja2Templates(directory=str(directory))  # échappement HTML actif
    templates.env.filters["filesize"] = filesize
    templates.env.filters["date_fr"] = date_fr
    templates.env.filters["date_short"] = date_short
    templates.env.filters["rich_text"] = rich_text
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
