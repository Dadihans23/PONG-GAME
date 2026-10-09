"""Vérification et enregistrement des fichiers téléversés.

Le type est déduit du contenu (signature binaire), jamais du nom ni du
Content-Type envoyés par le navigateur. Les noms de fichiers sont générés ici.
"""

from __future__ import annotations

import hashlib
import re
import secrets
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO


class UploadError(ValueError):
    """Fichier refusé ; le message est affiché à l'administrateur."""


IMAGE_TYPES = {
    "png": "image/png",
    "jpg": "image/jpeg",
    "webp": "image/webp",
    "gif": "image/gif",
    "svg": "image/svg+xml",
}

STORED_NAME = re.compile(r"^[a-f0-9]{32}\.(png|jpg|webp|gif|svg|apk)$")
VERSION_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z._+-]{0,31}$")

_SVG_FORBIDDEN = re.compile(
    rb"<\s*script|<\s*foreignObject|<!ENTITY|<!DOCTYPE|javascript:|\son[a-z]+\s*=",
    re.IGNORECASE,
)


def new_name(ext: str) -> str:
    return f"{secrets.token_hex(16)}.{ext}"


def sniff_image(head: bytes) -> str | None:
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if head.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "gif"
    return None


def _is_safe_svg(data: bytes) -> bool:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    if not re.search(r"<svg[\s>]", text, re.IGNORECASE):
        return False
    return _SVG_FORBIDDEN.search(data) is None


def _copy_limited(src: BinaryIO, dest: Path, max_bytes: int) -> tuple[int, str]:
    """Copie src dans dest en refusant au-delà de max_bytes. Renvoie (taille, sha256)."""
    digest = hashlib.sha256()
    size = 0
    try:
        with dest.open("xb") as out:
            while chunk := src.read(1024 * 1024):
                size += len(chunk)
                if size > max_bytes:
                    raise UploadError(
                        f"Fichier trop volumineux (maximum {max_bytes // (1024 * 1024)} Mo)."
                    )
                digest.update(chunk)
                out.write(chunk)
    except BaseException:
        dest.unlink(missing_ok=True)
        raise
    if size == 0:
        dest.unlink(missing_ok=True)
        raise UploadError("Le fichier est vide.")
    return size, digest.hexdigest()


def save_image(src: BinaryIO, folder: Path, max_bytes: int, allow_svg: bool) -> str:
    """Enregistre une image vérifiée et renvoie son nom de fichier."""
    data = src.read(max_bytes + 1)
    if not data:
        raise UploadError("Aucun fichier reçu.")
    if len(data) > max_bytes:
        raise UploadError(f"Image trop volumineuse (maximum {max_bytes // (1024 * 1024)} Mo).")
    ext = sniff_image(data[:16])
    if ext is None and allow_svg and _is_safe_svg(data):
        ext = "svg"
    if ext is None:
        allowed = "PNG, JPEG, WebP, GIF" + (" ou SVG" if allow_svg else "")
        raise UploadError(f"Ce fichier n'est pas une image acceptée ({allowed}).")
    folder.mkdir(parents=True, exist_ok=True)
    name = new_name(ext)
    (folder / name).write_bytes(data)
    return name


@dataclass
class SavedApk:
    filename: str
    size: int
    sha256: str


def save_apk(src: BinaryIO, folder: Path, max_bytes: int) -> SavedApk:
    """Enregistre un APK : un fichier ZIP qui contient AndroidManifest.xml."""
    folder.mkdir(parents=True, exist_ok=True)
    name = new_name("apk")
    dest = folder / name
    size, sha = _copy_limited(src, dest, max_bytes)
    try:
        if not zipfile.is_zipfile(dest):
            raise UploadError("Ce fichier n'est pas un APK (ce n'est pas une archive ZIP).")
        with zipfile.ZipFile(dest) as archive:
            if "AndroidManifest.xml" not in archive.namelist():
                raise UploadError("Ce fichier n'est pas un APK (AndroidManifest.xml absent).")
    except UploadError:
        dest.unlink(missing_ok=True)
        raise
    except (zipfile.BadZipFile, OSError) as exc:
        dest.unlink(missing_ok=True)
        raise UploadError("Archive APK illisible.") from exc
    return SavedApk(filename=name, size=size, sha256=sha)


def delete_file(folder: Path, name: str) -> None:
    if name and STORED_NAME.match(name):
        (folder / name).unlink(missing_ok=True)
