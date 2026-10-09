# Site de présentation de Tilto : FastAPI + Jinja2 + SQLite.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DATA_DIR=/data

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Utilisateur sans privilèges ; /data appartient à cet utilisateur pour que
# le volume nommé hérite des bons droits à sa création.
RUN groupadd --system --gid 10001 tilto \
 && useradd --system --uid 10001 --gid tilto --no-create-home --shell /usr/sbin/nologin tilto \
 && mkdir -p /data \
 && chown tilto:tilto /data

COPY app ./app

USER tilto
EXPOSE 8000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/sante', timeout=4).status == 200 else 1)"

# --proxy-headers : lit X-Forwarded-For / X-Forwarded-Proto, mais seulement
# depuis les adresses listées dans FORWARDED_ALLOW_IPS (variable lue par uvicorn).
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", \
     "--proxy-headers", "--no-server-header", "--timeout-keep-alive", "5"]
