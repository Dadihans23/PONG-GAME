# Site de présentation de Tilto

Petit site FastAPI (rendu serveur Jinja2, SQLite, fichiers sur disque) qui présente le jeu, propose l'APK en téléchargement et le lien Play Store, publie la politique de confidentialité et les mentions légales, reçoit les messages du formulaire de contact, et offre une administration protégée par mot de passe pour tout modifier sans toucher au code.

## Organisation

```
site/
├── app/
│   ├── main.py            création de l'application (uvicorn --factory app.main:create_app)
│   ├── config.py          variables d'environnement
│   ├── db.py              schéma SQLite, contenu initial, requêtes
│   ├── security.py        mot de passe scrypt, CSRF, limitation, taille des requêtes, en-têtes
│   ├── uploads.py         vérification et enregistrement des images et des APK
│   ├── render.py          gabarits et filtres (taille, date, date courte, texte enrichi)
│   ├── routes_public.py   /, /confidentialite, /mentions-legales, /contact, /telecharger, /media/…, /sante
│   ├── routes_admin.py    /admin/…
│   ├── contact.py         formulaire de contact : jeton, délai, validation
│   ├── mailer.py          notification SMTP facultative des messages de contact
│   ├── reseed_v2.py       commande facultative : textes v1 → textes v2 (voir plus bas)
│   ├── hashpw.py          génération du hachage du mot de passe et de la clé secrète
│   ├── templates/         gabarits HTML (publics, et admin/)
│   ├── seed/              logo initial du studio, copié dans les données au premier démarrage
│   └── static/            css/site.css, js/admin.js, fonts/ (Archivo)
├── tests/                 pytest
├── Dockerfile, docker-compose.yml, .env.example
└── requirements.txt (production), requirements-dev.txt (tests)
```

Les données (base `tilto.sqlite3`, `uploads/images`, `uploads/apk`) vivent dans `DATA_DIR` : le volume Docker `tilto-data` en production, `./data` en local. Rien n'est écrit dans le dossier du code.

## Lancer en local sans Docker

```bash
cd site
python -m venv .venv
.venv/bin/pip install -r requirements-dev.txt        # Windows : .venv\Scripts\pip
cp .env.example .env
.venv/bin/python -m app.hashpw --secret               # copier la ligne SECRET_KEY=… dans .env
.venv/bin/python -m app.hashpw                        # copier la ligne ADMIN_PASSWORD_HASH=… dans .env
set -a; . ./.env; set +a                              # charger .env dans le shell
.venv/bin/uvicorn app.main:create_app --factory --port 8085
```

Le site répond sur http://127.0.0.1:8085, l'administration sur http://127.0.0.1:8085/admin.

Tests : `.venv/bin/python -m pytest`

## Lancer avec Docker

```bash
cd site
cp .env.example .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret   # -> SECRET_KEY dans .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw            # -> ADMIN_PASSWORD_HASH dans .env
docker compose up -d --build
```

Au premier démarrage, la base et le contenu initial sont créés automatiquement : textes de la maquette « Tilto Site v2 », corrigés (haut de page et fiche technique, 4 arguments avec leurs caractéristiques, comparatif Solo / Duel, 3 étapes, barème, 4 captures avec description, 6 questions fréquentes, étapes d'installation de l'APK, pied de page, politique de confidentialité avec la section « Formulaire de contact »), studio Nexora et son logo clair, hébergeur Contabo GmbH dans les mentions légales. Restent à saisir dans l'administration : le lien Play Store, les images des captures, l'APK (ses notes de version 1.0.0 sont proposées au premier dépôt) et les mentions légales (le tableau de bord signale « Mentions légales incomplètes » tant que les champs obligatoires sont vides).

## Installation sur le VPS

Docker est déjà installé ; le site n'utilise que le port choisi dans `HOST_PORT` (8085 par défaut) et ne touche ni à 80 ni à 443.

```bash
# 1. Récupérer le dossier (clone du dépôt, ou copie du seul dossier site/)
git clone <url-du-depot> tilto && cd tilto/site
#   ou depuis le poste : scp -r site/ utilisateur@vps:~/tilto-site && ssh utilisateur@vps && cd ~/tilto-site

# 2. Créer .env
cp .env.example .env
docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret
docker compose run --rm --no-deps tilto-site python -m app.hashpw
nano .env          # coller SECRET_KEY et ADMIN_PASSWORD_HASH, ajuster HOST_PORT si 8085 est pris
chmod 600 .env

# 3. Démarrer
docker compose up -d --build

# 4. Vérifier
docker compose ps                         # STATUS doit afficher (healthy)
curl -s http://127.0.0.1:8085/sante       # {"status":"ok"}
docker compose logs --tail 50
```

Le site est alors visible sur `http://<ip-du-vps>:8085` (ouvrir ce port dans le pare-feu si besoin, par exemple `ufw allow 8085/tcp`).

### Mettre à jour

```bash
git pull                   # ou recopier le dossier site/
docker compose up -d --build
```

La base et les fichiers sont dans le volume `tilto-data` : la reconstruction de l'image ne les touche pas. Le schéma est créé avec `CREATE TABLE IF NOT EXISTS`, les colonnes ajoutées par une version sont ajoutées aux bases existantes (`MIGRATIONS` dans `db.py`), et le contenu initial n'est inséré que s'il manque.

### Sauvegarder et restaurer le volume

```bash
# Sauvegarde (archive datée dans le dossier courant)
docker run --rm -v tilto-data:/data -v "$PWD":/backup alpine \
  tar czf /backup/tilto-data-$(date +%F).tar.gz -C /data .

# Restauration (site arrêté)
docker compose down
docker run --rm -v tilto-data:/data -v "$PWD":/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/tilto-data-AAAA-MM-JJ.tar.gz -C /data"
docker compose up -d
```

Pour une copie cohérente de la base pendant que le site tourne : `docker compose exec tilto-site python -c "import sqlite3; s=sqlite3.connect('/data/tilto.sqlite3'); d=sqlite3.connect('/data/backup.sqlite3'); s.backup(d)"`, puis sauvegarder le volume.

### Changer le mot de passe

Générer un nouveau hachage (`python -m app.hashpw`), le mettre dans `.env`, puis `docker compose up -d`. Toutes les sessions ouvertes sont invalidées.

## Plus tard : nom de domaine, Nginx et HTTPS

Quand le domaine pointe vers le VPS, faire passer le site par le serveur web existant :

1. Dans `.env` : `HOST_BIND=127.0.0.1` (le port n'est plus joignable de l'extérieur), `FORWARDED_ALLOW_IPS=*` (uvicorn fait confiance aux en-têtes `X-Forwarded-*` envoyés par Nginx ; sans risque puisque seul le serveur local peut joindre le port), puis `COOKIE_SECURE=true` une fois le HTTPS actif. `docker compose up -d`.
2. FastAPI/uvicorn tourne déjà avec `--proxy-headers` (voir `Dockerfile`) : avec `FORWARDED_ALLOW_IPS` réglé, il utilise la vraie IP du visiteur (limitation des connexions) et le schéma `https`.
3. Bloc Nginx (par exemple `/etc/nginx/sites-available/tilto`) :

```nginx
server {
    listen 80;
    server_name tilto.exemple.com;

    # Taille d'upload : au moins MAX_APK_MB + 2 Mo
    client_max_body_size 210m;

    location / {
        proxy_pass http://127.0.0.1:8085;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host  $host;

        # Dépôt d'un APK de 200 Mo sur une connexion lente
        proxy_read_timeout    300s;
        proxy_send_timeout    300s;
        proxy_request_buffering off;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/tilto /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

4. HTTPS : `sudo certbot --nginx -d tilto.exemple.com` (Certbot ajoute le bloc `listen 443 ssl` et la redirection), ou le mécanisme du serveur web déjà en place (Caddy, Traefik… : même principe, proxy vers `127.0.0.1:8085` avec les en-têtes `X-Forwarded-*` et une taille de requête suffisante). Puis `COOKIE_SECURE=true` dans `.env` et `docker compose up -d` (le site envoie alors aussi l'en-tête HSTS).

## Sécurité, en bref

- Mot de passe unique, stocké uniquement sous forme de hachage scrypt (N = 2^16, r = 8), vérifié en temps constant ; 5 échecs par IP en 15 minutes bloquent la connexion (réglable).
- Session dans un cookie signé (`itsdangerous`), `HttpOnly`, `SameSite=Lax`, limité au chemin `/admin`, `Secure` si `COOKIE_SECURE=true`, durée maximale `SESSION_MAX_AGE` ; les pages publiques ne déposent aucun cookie, sauf `/contact` (voir ci-dessous).
- Formulaire de contact : jeton anti-CSRF « double envoi » (cookie technique aléatoire `tilto_contact`, `HttpOnly`, `SameSite=Strict`, limité au chemin `/contact`, effacé à la fermeture du navigateur, plus un jeton signé avec `SECRET_KEY` dans le formulaire), champ piège invisible (`website`, un envoi qui le remplit est ignoré en silence), délai minimal `CONTACT_MIN_SECONDS` entre affichage et envoi, jeton valable 2 heures, limitation à `CONTACT_MAX_PER_HOUR` messages par IP et `CONTACT_GLOBAL_PER_HOUR` au total par heure (en mémoire), corps limité à 32 Ko, message à 2000 caractères, e-mail validé et sans retour à la ligne (pas d'injection d'en-têtes dans la notification). Aucun service externe ni captcha. Aucune adresse IP n'est enregistrée avec les messages.
- Jeton CSRF sur tous les formulaires, y compris connexion et déconnexion.
- Fichiers : type vérifié sur le contenu (signature PNG/JPEG/WebP/GIF, SVG sans script pour le logo, APK = ZIP contenant `AndroidManifest.xml`), nom généré par le serveur, taille limitée avant même la lecture du formulaire (413).
- En-têtes : CSP stricte (aucun script en ligne), `X-Frame-Options`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, HSTS en HTTPS.
- Pas de mode debug, pas de documentation `/docs` exposée, conteneur sans privilèges (utilisateur 10001, `no-new-privileges`).

## Formulaire de contact et notification par e-mail

`/contact` affiche le formulaire (nom facultatif, e-mail, sujet : Question, Problème technique, Suggestion, Autre, message de 2000 caractères au plus) ; un envoi réussi mène à `/contact/merci`. Les messages sont enregistrés en base et se lisent dans **Administration › Messages** (liste, lecture, marquer comme lu ou non lu, supprimer, bouton « Répondre par e-mail » qui ouvre un `mailto:`). Le nombre de non-lus s'affiche dans le menu et sur le tableau de bord.

Notification facultative, variables de `.env` (voir `.env.example`) :

| Variable | Rôle |
|---|---|
| `SMTP_HOST` | serveur SMTP (vide = aucune notification) |
| `SMTP_PORT` | 587 (STARTTLS, défaut) ou 465 (SSL) |
| `SMTP_SECURITY` | facultatif : `starttls` ou `ssl` (déduit du port sinon) |
| `SMTP_USER`, `SMTP_PASSWORD` | identifiants (vide = pas d'authentification) |
| `SMTP_FROM` | expéditeur (adresse autorisée par le serveur SMTP) |
| `CONTACT_NOTIFY_TO` | destinataire de la notification |
| `CONTACT_MAX_PER_HOUR`, `CONTACT_GLOBAL_PER_HOUR`, `CONTACT_MIN_SECONDS` | limitations (3, 30, 3 par défaut) |

La notification part en tâche de fond après la réponse au visiteur ; son « Répondre » écrit directement au visiteur (`Reply-To`). Un échec (serveur injoignable, mauvais mot de passe) est écrit dans `docker compose logs` (`ERROR tilto.mailer: …`) et le message reste en base. Sans `SMTP_HOST`, `SMTP_FROM` et `CONTACT_NOTIFY_TO`, rien n'est envoyé.

## Mise à jour vers le site v2 : ce qui change en production

Au premier démarrage de la v2, sans rien effacer :

- nouvelles colonnes : `content_item.short_body` (texte court mobile des arguments), `screenshot.description`, `apk_release.release_notes` et `release_date` ;
- nouvelles tables : `spec_row` (fiche technique, comparatif, barème, étapes d'installation, caractéristiques des arguments), `faq`, `contact_message` ;
- nouveaux réglages (sur-titres, titres de sections, textes du pied de page, mentions légales…) avec leur texte initial ;
- contenus v2 insérés une seule fois (repère interne `_seed_v2`) : fiche technique, comparatif, barème, installation, 6 questions de FAQ, caractéristiques et texte court des 4 arguments existants (reconnus à leur sur-titre INCLINE, À DEUX, SENSIBILITÉ, RECORDS), notes de version de l'APK `1.0.0` s'il est déjà déposé et sans notes. Un tableau vidé ensuite dans l'administration n'est pas recréé.

Les textes **déjà en base ne sont pas écrasés**. Après le déploiement, la page affichera donc encore les textes v1 suivants, à mettre à jour :

1. **Textes › Accroche** : en v1 elle contient aussi « Seul contre l'ordinateur, ou à deux sur le même Wi-Fi. », qui fait maintenant doublon avec le nouveau texte de présentation. Texte v2 : « Le Pong qu'on joue en inclinant son téléphone. »
2. **Textes › Phrase du bloc de téléchargement** : v2 « Le Play Store installe les mises à jour tout seul. L'APK sert si tu n'as pas le Play Store ou si tu veux l'installer à la main. » (à ne changer qu'une fois l'app sur le Play Store).
3. **Arguments** : titres et textes v2 des 4 arguments (le texte court et les caractéristiques sont déjà ajoutés).
4. **Comment jouer** : précisions v2 des 3 étapes, titre de l'étape 2 « Tape l'écran pour lancer la balle. ».
5. **Captures** : légendes v2 (L'accueil, En solo, En duel, Fin du duel), descriptions, et une 4e capture « Fin du duel ». Vérifier que chaque image correspond à sa nouvelle légende.
6. **Confidentialité** : ajouter la section « Formulaire de contact » (texte dans `db.py`, `PRIVACY_CONTACT_SECTION`) et changer la date de mise à jour.
7. **Mentions légales** : éditeur (nom, forme juridique, adresse, e-mail, directeur de la publication) et adresse et téléphone de l'hébergeur Contabo GmbH, à vérifier sur le site de Contabo.
8. **APK** : relire les notes de version de la 1.0.0 (page APK) et, si besoin, la date de version.
9. Facultatif : variables SMTP dans `.env` sur le VPS, puis `docker compose up -d`.

Les points 1 à 6 peuvent aussi être faits en une fois, après une sauvegarde de la base :

```bash
docker compose exec tilto-site python -m app.reseed_v2            # liste les changements, ne modifie rien
docker compose exec tilto-site python -m app.reseed_v2 --apply    # demande « oui », puis applique
```

La commande remplace, position par position, les textes des arguments (et leurs caractéristiques), des étapes et des légendes et descriptions des captures par ceux de la v2 (images conservées, capture manquante ajoutée sans image), l'accroche et la phrase de téléchargement, et ajoute la section contact à la politique de confidentialité (date mise à aujourd'hui). Elle ne touche ni aux APK, ni aux images, ni à la FAQ, ni aux tableaux, ni aux mentions légales.

## Habiller les gabarits (maquette « Tilto Site v2 »)

Les données suivent les sections de la maquette `maquette/Corrections et validation des maquettes/Tilto Site v2.dc (1).html` (planches 3a ordinateur, 3b mobile). Les gabarits actuels affichent ces données avec un balisage minimal, sans habillage : l'habillage ne touche que les gabarits publics, `app/static/css/site.css` et `app/static/js/`. Routes et base ne changent pas. Toutes les valeurs sont échappées par Jinja ; `|rich_text` pour les textes longs à intertitres.

Variables communes à toutes les pages publiques (`routes_public.site_context`) :

| Variable | Contenu |
|---|---|
| `site` | tous les réglages (clés ci-dessous), plus `site.studio_logo_url` (vide sans logo) |
| `year` | année en cours |
| `apk` | APK courant ou `None` : `version`, `size_bytes` (`\|filesize`), `sha256` (empreinte complète), `uploaded_at`, `date` (date de version, ou de dépôt, AAAA-MM-JJ ; `\|date_short` → « 9 oct. 2026 », `\|date_fr` → « 9 octobre 2026 »), `notes` (liste des nouveautés, une par ligne saisie), `download_name` (ex. `Tilto-1.0.0.apk`) |
| `faq` | questions : `anchor`, `question`, `answer`, `short_answer` (mobile, peut être vide), `footer_label` |
| `footer_columns` | colonnes du pied de page : `[{title, links: [{label, href, external}]}]` — Le jeu (Solo et Duel, Comment jouer, Captures, Nouveautés x.y.z), Aide (Questions fréquentes, Installer l'APK, puis chaque question dont `footer_label` est rempli), Télécharger (Google Play, APK vx · taille ; colonne absente sans l'un ni l'autre), studio (Contact, Politique de confidentialité, Mentions légales) |

Page d'accueil (`index.html`) :

| Section de la maquette | Données |
|---|---|
| Barre de navigation (Le jeu, Solo ou Duel, Comment jouer, Captures, FAQ, Installer l'APK ; « v1.0.0 · 9 oct. 2026 ») | ancres `#le-jeu`, `#solo-duel`, `#comment-jouer`, `#captures`, `#faq`, `#installer-apk`, `#telecharger`, `#nouveautes`, `#bareme` ; `apk.version`, `apk.date\|date_short`. Pas de bandeau « Nouveau », pas de sélecteur de langue. |
| Haut de page | `site.hero_kicker`, `site.game_name`, `site.tagline`, `site.hero_text` (ordinateur), `site.hero_text_short` (mobile), `site.play_store_url` (vide = bouton masqué), `apk` (version, taille, « sans Play Store » est du gabarit), `site.hero_note` |
| Fiche technique (MODES, JOUEURS…) | `hero_specs` : `label`, `value` (la version mobile de la maquette n'en montre que 3 : au gabarit de choisir) |
| Démo | `site.hero_demo_text` (légende) ; l'animation est du gabarit |
| Section « Ce qui change » | `site.features_kicker`, `site.features_title`, `site.features_intro` |
| 4 arguments (01 à 04) | `features` : `kicker`, `title`, `body`, `short_body` (mobile, peut être vide), `specs` (liste de `label`, `value`) ; le numéro est `loop.index` |
| Solo ou Duel | `site.compare_kicker`, `site.compare_title`, `compare` : `label` (critère), `value` (Solo), `value2` (Duel) |
| Comment jouer | `site.steps_title`, `steps` : `title`, `body` |
| Barème en solo | `site.scoring_title`, `scoring` : `label`, `value` |
| Captures | `site.screens_title`, `site.screens_intro`, `site.screens_note`, `screenshots` : `filename` (`/media/<filename>`, vide = emplacement réservé), `caption`, `description` |
| Questions fréquentes | `site.faq_title`, `site.faq_subtitle`, `faq` (chaque question porte `id="{{ q.anchor }}"`, cible des liens du pied de page), `site.faq_text` + lien `/contact` |
| Télécharge Tilto | `site.download_title`, `site.download_text`, `apk` |
| Installer l'APK | `site.install_title`, `install_steps` (`label` = texte de l'étape), `site.install_note` (phrase Play Store), `apk.sha256` |
| Nouveautés | `site.notes_title`, `apk.version`, `apk.date`, `apk.notes` |
| Pied de page (`base.html`) | `site.footer_text`, `site.studio_logo_url`, `footer_columns`, « Un jeu de `site.studio_name` · © `year` · `site.game_name` `apk.version` », `site.footer_note`, `site.footer_trademark` |

Autres pages :

| Page | Gabarit | Données |
|---|---|---|
| `/confidentialite` (3c) | `privacy.html` | `site.privacy_updated\|date_fr`, `site.privacy_policy\|rich_text` |
| `/mentions-legales` | `legal.html` | `legal_sections` : `[{title, rows: [{label, value}]}]` (Éditeur du site, Directeur de la publication, Hébergeur ; champs vides omis), `site.legal_extra\|rich_text`, `site.legal_updated`, ou directement `site.legal_publisher`, `legal_form`, `legal_registration`, `legal_address`, `legal_email`, `legal_phone`, `legal_director`, `legal_host_name`, `legal_host_address`, `legal_host_phone` |
| `/contact` | `contact.html` | `form` (`name`, `email`, `subject`, `message`, `errors` : liste de messages en français), `subjects`, `max_message`, `contact_token` (champ caché `csrf_token`, obligatoire), `honeypot` (nom du champ piège, à garder invisible avec la classe `contact-hp` définie à la fin de `site.css`), `site.contact_email` (adresse affichée si remplie) |
| `/contact/merci` | `contact_sent.html` | variables communes |
| Erreurs | `error.html` | `status`, `message` (sans `site` : le pied de page affiche des liens fixes) |

La CSP interdit le JavaScript et les styles en ligne (`style="…"`) ainsi que toute ressource externe : scripts dans `app/static/js/` chargés par `<script src>`, polices dans `app/static/fonts/`. Les éléments purement décoratifs de la maquette (classement d'exemple, curseur Douce / Vive, téléphones de Léa et Tom, partie de démonstration) relèvent du gabarit, pas de la base.

## Déploiement automatique (branche `prod`)

Chaque push sur la branche `prod` lance `.github/workflows/deploy-prod.yml` : analyse et tests de l'app Flutter, tests du site, puis copie de `site/` sur le VPS (rsync) et `docker compose up -d --build`. Le `.env` et le volume `tilto-data` restent sur le serveur et ne sont jamais écrasés. Un déploiement peut aussi être relancé à la main (onglet Actions › Déploiement prod › Run workflow).

### Mise en place (une seule fois)

1. **Sur ton PC**, crée une clé SSH dédiée au déploiement, sans mot de passe :
   ```bash
   ssh-keygen -t ed25519 -C "deploy-tilto" -f ~/.ssh/tilto_deploy -N ""
   ```
2. **Autorise cette clé sur le VPS** (demande ton mot de passe une dernière fois) :
   ```bash
   ssh-copy-id -i ~/.ssh/tilto_deploy.pub hans@79.143.190.190
   ```
   Sous Windows sans `ssh-copy-id` : `type $env:USERPROFILE\.ssh\tilto_deploy.pub | ssh hans@79.143.190.190 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"`
3. **Sur le VPS**, prépare le dossier et le `.env` (une seule fois) :
   ```bash
   mkdir -p ~/tilto-site && cd ~/tilto-site
   # copie .env.example depuis le dépôt, puis :
   cp .env.example .env && chmod 600 .env
   # choisis un HOST_PORT libre (vérifie avec : ss -ltnp | grep :8085)
   ```
   Les valeurs `SECRET_KEY` et `ADMIN_PASSWORD_HASH` se génèrent après le premier déploiement avec
   `docker compose run --rm --no-deps tilto-site python -m app.hashpw --secret` puis sans `--secret`.
   L'utilisateur `hans` doit pouvoir lancer `docker` sans `sudo` (groupe `docker`).
4. **Sur GitHub** (dépôt › Settings › Secrets and variables › Actions) :
   - Secrets : `DEPLOY_HOST` = `79.143.190.190`, `DEPLOY_USER` = `hans`,
     `DEPLOY_SSH_KEY` = contenu de `~/.ssh/tilto_deploy` (la clé **privée**),
     `DEPLOY_KNOWN_HOSTS` = sortie de `ssh-keyscan 79.143.190.190`.
   - Variable : `DEPLOY_PATH` = `/home/hans/tilto-site`.
   - Optionnel : Settings › Environments › `prod` › « Required reviewers » pour valider chaque déploiement à la main.
5. **Crée la branche `prod`** et pousse : `git push origin main:prod`.
