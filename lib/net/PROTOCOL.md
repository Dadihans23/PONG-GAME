# Protocole réseau du duel local

Version du protocole : **1** (`protocolVersion` dans `protocol.dart`).

Deux canaux :

| Canal | Transport | Port | Rôle |
|---|---|---|---|
| Jeu | WebSocket (TCP), chemin `/pong`, trames texte | 47800 (repli sur un port libre s'il est occupé) | Salon, partie, battement de cœur |
| Découverte | UDP broadcast + unicast | 47801 | Annonce des parties, sondes |

La couche réseau ne connaît aucune règle du jeu : l'état de jeu circule comme une
charge utile JSON opaque produite par le moteur (`toJson()` / `fromJson()` des
modèles du jeu).

---

## 1. Canal de jeu (WebSocket)

### Enveloppe

Chaque trame texte est un objet JSON :

```json
{ "v": 1, "type": "paddle", "...": "champs du message" }
```

- `v` (entier, obligatoire) : version du protocole.
- `type` (texte, obligatoire) : type du message.
- Les champs inconnus sont ignorés (compatibilité ascendante).
- Taille maximale d'une trame : **8192 caractères** (`maxFrameLength`).
- Les trames binaires sont ignorées.

### Messages

| type | Sens | Champs | Contraintes |
|---|---|---|---|
| `join` | Client → Host | `name` | pseudo non vide après `trim`, ≤ 24 caractères. Décodé quelle que soit `v`, pour que le Host puisse refuser une version différente |
| `welcome` | Host → Client | `hostName` | pseudo du Host, mêmes contraintes |
| `reject` | Host → Client | `reason` | `full`, `version`, `bad_request`, `closing` ; toute autre valeur est lue `unknown`. Le Host ferme ensuite la connexion |
| `ready` | les deux | `ready` | booléen ; chaque joueur annonce son propre statut |
| `start` | Host → Client | `countdown` | entier de 0 à 10 (secondes avant le service) |
| `paddle` | Client → Host | `seq`, `x` | `seq` entier ≥ 0 croissant ; `x` réel fini dans [-1, 1], **coordonnées du court, jamais inversées** |
| `game_state` | Host → Client | `seq`, `state` | `seq` entier ≥ 0 croissant ; `state` objet JSON opaque (modèle du jeu) |
| `game_over` | Host → Client | `winner`, `state`? | `winner` = `host` ou `client` ; `state` objet opaque facultatif (état final) |
| `rematch` | les deux | aucun | demande de revanche ; le Host décide et renvoie `start` |
| `leave` | les deux | `reason`? | texte ≤ 64 caractères ; départ volontaire, la connexion se ferme ensuite |
| `ping` | les deux | `t` | entier ≥ 0 (horloge de l'émetteur, en ms) |
| `pong` | les deux | `t` | le `t` du `ping` reçu, renvoyé tel quel |

Exemples :

```json
{"v":1,"type":"join","name":"Hans"}
{"v":1,"type":"welcome","hostName":"Awa"}
{"v":1,"type":"reject","reason":"full"}
{"v":1,"type":"ready","ready":true}
{"v":1,"type":"start","countdown":3}
{"v":1,"type":"paddle","seq":812,"x":-0.42}
{"v":1,"type":"game_state","seq":1543,"state":{"ball":{"x":0.1,"y":-0.3}, "score":{"host":2,"client":1}}}
{"v":1,"type":"game_over","winner":"host","state":{"score":{"host":5,"client":3}}}
{"v":1,"type":"rematch"}
{"v":1,"type":"leave","reason":"client_left"}
{"v":1,"type":"ping","t":120034}
{"v":1,"type":"pong","t":120034}
```

### Déroulement

```text
Client                                  Host
  │ ── connexion WebSocket ─────────────▶ │  (3e connexion : reject full, fermeture)
  │ ── join {name} ─────────────────────▶ │  (pas de join en 3 s : reject bad_request)
  │ ◀──────────────── welcome {hostName}  │  (ou reject version / full)
  │ ── ready {true} ────────────────────▶ │
  │ ◀──────────────────── ready {true} ── │
  │ ◀──────────────── start {countdown}   │
  │ ── paddle {seq,x}   × 30 / s ───────▶ │
  │ ◀────── game_state {seq,state} × 30/s │
  │ ◀──────────── game_over {winner}      │
  │ ── rematch ─────────────────────────▶ │ ◀─ (ou rematch du Host)
  │ ◀──────────────── start {countdown}   │
  │ ── leave ───────────────────────────▶ │  fermeture
```

### Rôles : messages acceptés

- Le Host n'accepte du Client que `join` (une fois), `ready`, `paddle`, `rematch`,
  `leave`, `ping`, `pong`. Tout autre type est ignoré et journalisé.
- Le Client n'accepte du Host que `welcome`/`reject` (avant d'être accepté), puis
  `ready`, `start`, `game_state`, `game_over`, `rematch`, `leave`, `ping`, `pong`.
- `paddle` et `game_state` dont le `seq` n'est pas supérieur au précédent sont
  ignorés (protection pour un futur transport non ordonné).

### Décodage défensif

JSON invalide, trame trop longue, objet attendu mais autre chose reçu, `type`
inconnu, `v` différente (hors `join`), champ manquant, mauvais type, valeur hors
bornes (dont `x` infini) : **le message est ignoré et journalisé** (journal
`pong.net`), la connexion continue. Aucune exception ne remonte.

À l'envoi, un message non encodable (par exemple un `NaN` dans l'état du jeu,
que JSON ne sait pas représenter) ou trop long est abandonné et journalisé.

### Battement de cœur et coupures

- Toute trame reçue prouve que le pair est vivant.
- Chaque côté envoie un `ping` toutes les **1 s** ; le pair répond `pong`
  (mesure de l'aller-retour, `roundTripTime`).
- Rien reçu pendant **4 s** : la connexion est déclarée perdue
  (`DisconnectReason.timeout`) et fermée. Vérification toutes les 250 ms.

| Cas | Ce que voit l'autre côté | Délai |
|---|---|---|
| `leave` puis fermeture (bouton Quitter) | `PeerDisconnected(left)` | immédiat |
| App tuée, socket fermé par le système | `PeerDisconnected(closed)` | immédiat |
| Wi-Fi coupé, téléphone hors de portée, app gelée | `PeerDisconnected(timeout)` | 4 à 4,25 s |
| 3e joueur | `JoinRejected(full)` pour lui ; rien ne change pour les deux autres | immédiat |

Le Host qui perd son Client **reste en écoute** (retour au salon). Le Client qui
perd le Host termine sa session.

---

## 2. Canal de découverte (UDP 47801)

Paquets JSON en UTF-8, ≤ 1024 octets, tous avec `"app": "pong_game"` (les autres
sont ignorés).

### Annonce (Host → broadcast, et réponse unicast à une sonde)

```json
{"app":"pong_game","type":"announce","v":1,"id":"3fa9c01b","name":"Partie de Awa","port":47800,"players":1,"max":2}
```

| Champ | Contrainte |
|---|---|
| `id` | texte 1 à 32 caractères, aléatoire par partie |
| `name` | texte non vide, ≤ 40 caractères |
| `port` | port WebSocket, 1 à 65535 |
| `players` / `max` | 0 ≤ players ≤ max ≤ 8 (2 pour le duel) |
| `v` | version du protocole du Host ; une autre version est listée mais marquée incompatible |

L'adresse du Host est lue sur le paquet reçu, pas dans son contenu.

### Sonde (Client → broadcast)

```json
{"app":"pong_game","type":"probe","v":1}
```

Le Host répond par une annonce **unicast** à l'adresse et au port de la sonde.

### Cadence

- Annonce du Host : toutes les **1 s**, et aussitôt à chaque changement du nombre
  de joueurs.
- Sonde du Client : toutes les **1 s**.
- Une partie non revue depuis **3,5 s** est retirée de la liste.

### Adresses de broadcast

Chaque broadcast part vers `255.255.255.255` **et** vers `a.b.c.255` pour chaque
interface IPv4 du téléphone (hors boucle locale et données mobiles `rmnet*`,
`ccmni*`), recalculées toutes les 5 s.

---

## 3. Limites connues

- **Masque supposé /24** : Dart ne donne pas le masque des interfaces. Les points
  d'accès Android et les box domestiques sont en /24 ; sur un réseau plus large
  (/16, réseaux d'entreprise), seul `255.255.255.255` et les sondes restent.
- **Point d'accès Android sans données mobiles** : `255.255.255.255` peut partir
  sur une autre interface ou échouer (« Network is unreachable ») ; l'adresse
  dirigée du point d'accès (souvent `192.168.43.255`, aléatoire depuis Android 11)
  et la réponse unicast aux sondes couvrent ce cas.
- **Isolation des clients** (« AP isolation ») sur certains routeurs publics ou
  d'hôtel : les deux téléphones ne peuvent pas se joindre du tout, ni en UDP ni
  en TCP. Rien à faire côté app ; utiliser le point d'accès d'un des téléphones.
- **Filtrage du broadcast** par la puce Wi-Fi en veille : atténué par le
  `MulticastLock` (Android) et par les sondes.
- **Pare-feu** : Android n'en a pas pour le trafic local ; un PC Windows de test
  doit autoriser les ports 47800/TCP et 47801/UDP.
- **Arrière-plan** : la couche réseau continue de tourner quand l'app passe en
  arrière-plan (les minuteurs Dart tournent, le `Ticker` du jeu s'arrête). Les
  écrans doivent donc **fermer la session** sur `AppLifecycleState.paused` (pas
  de pause en duel). Si le système gèle l'app avant, l'autre côté le détecte par
  le battement de cœur (4 s).
- **Taille de trame** : `dart:io` ne limite pas la taille d'une trame WebSocket
  reçue ; elle est ignorée après réception si elle dépasse 8192 caractères.
  Acceptable sur un réseau local à deux joueurs.
- **IPv4 seulement**.
