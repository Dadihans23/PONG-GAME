"""Notification par e-mail des messages de contact (facultative).

Activée seulement si SMTP_HOST, SMTP_FROM et CONTACT_NOTIFY_TO sont définis.
L'envoi se fait en tâche de fond, après la réponse au visiteur : un échec est
journalisé et n'empêche jamais l'enregistrement du message en base.
"""

from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr, make_msgid

from .config import SmtpConfig

log = logging.getLogger("tilto.mailer")

SMTP_TIMEOUT = 20


def build_notification(cfg: SmtpConfig, message: dict, site_name: str,
                       admin_url: str = "") -> EmailMessage:
    """E-mail envoyé au propriétaire. « Répondre » écrit directement au visiteur."""
    mail = EmailMessage()
    mail["From"] = formataddr((f"{site_name} · site", cfg.sender))
    mail["To"] = cfg.notify_to
    # Le nom et l'adresse ont été validés (une ligne, pas de caractère de contrôle).
    mail["Reply-To"] = formataddr((message.get("name", ""), message["email"]))
    mail["Subject"] = f"[{site_name}] {message['subject']} : nouveau message"
    mail["Message-ID"] = make_msgid(domain=cfg.sender.rsplit("@", 1)[-1])
    lines = [
        f"Nouveau message reçu par le formulaire de contact de {site_name}.",
        "",
        f"Nom : {message.get('name') or '(non indiqué)'}",
        f"E-mail : {message['email']}",
        f"Sujet : {message['subject']}",
        "",
        message["message"],
        "",
        "--",
        "Répondez simplement à cet e-mail pour écrire à l'expéditeur.",
    ]
    if admin_url:
        lines.append(f"Tous les messages : {admin_url}")
    mail.set_content("\n".join(lines))
    return mail


def send(cfg: SmtpConfig, mail: EmailMessage) -> None:
    context = ssl.create_default_context()
    if cfg.security == "ssl":
        server: smtplib.SMTP = smtplib.SMTP_SSL(cfg.host, cfg.port, timeout=SMTP_TIMEOUT,
                                                context=context)
    else:
        server = smtplib.SMTP(cfg.host, cfg.port, timeout=SMTP_TIMEOUT)
    with server:
        if cfg.security == "starttls":
            server.starttls(context=context)
        if cfg.user:
            server.login(cfg.user, cfg.password)
        server.send_message(mail)


def notify_contact(cfg: SmtpConfig, message: dict, site_name: str, admin_url: str = "") -> bool:
    """Tâche de fond : envoie la notification, journalise l'échec. Renvoie True si envoyé."""
    try:
        send(cfg, build_notification(cfg, message, site_name, admin_url))
    except Exception:  # noqa: BLE001 — réseau, authentification, TLS… : on journalise
        log.exception("Notification du message de contact impossible (SMTP %s:%s)",
                      cfg.host, cfg.port)
        return False
    log.info("Notification du message de contact envoyée à %s", cfg.notify_to)
    return True
