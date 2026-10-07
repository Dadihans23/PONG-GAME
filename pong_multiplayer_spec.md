# Pong Flutter — Évolution vers le Multijoueur Local

## 1. Contexte du projet

Le projet est un jeu de **Pong développé avec Flutter**.

La première version du jeu existe déjà et fonctionne en mode **solo**. Le joueur contrôle sa raquette en utilisant **l'accéléromètre du téléphone** : en inclinant le téléphone, la position de la raquette change.

L'objectif est maintenant de faire évoluer ce jeu vers un **Pong multijoueur local**, inspiré du principe de multijoueur local de jeux comme Mini Militia.

> Important : il ne faut pas réécrire inutilement le jeu existant. Il faut conserver au maximum la logique, les écrans et les composants déjà développés et ajouter progressivement la couche multijoueur.

---

# 2. Objectif final

Permettre à deux personnes de jouer au Pong :

- avec deux smartphones ;
- sans avoir besoin d'un PC ;
- sans avoir besoin d'Internet ;
- en étant sur le même réseau local Wi-Fi ;
- idéalement via le hotspot Wi-Fi de l'un des téléphones.

Exemple :

```text
                Wi-Fi local
                    │
          ┌─────────┴─────────┐
          │                   │
       📱 Joueur 1         📱 Joueur 2
          │                   │
       Flutter              Flutter
          │                   │
       Accéléromètre       Accéléromètre
```

Internet n'est pas nécessaire pour le mode **Local Multiplayer**.

---

# 3. Architecture retenue

## 3.1 Pas de serveur cloud pour le mode local

Pour ce mode, on ne veut pas dépendre d'un serveur FastAPI distant.

Le téléphone du joueur qui crée la partie devient temporairement le **Host**.

```text
                    📱 PLAYER 1
                    ┌──────────────┐
                    │ Flutter      │
                    │              │
                    │ Pong Game    │
                    │ Game Host    │
                    │              │
                    │ Game Engine  │
                    └──────┬───────┘
                           │
                       Wi-Fi local
                           │
                    ┌──────▼───────┐
                    │ 📱 PLAYER 2  │
                    │              │
                    │ Flutter      │
                    │ Game Client  │
                    └──────────────┘
```

Le téléphone Host joue donc aussi le rôle de serveur local.

---

# 4. Rôle du Host

Le Host est la source de vérité de la partie.

Il doit notamment être responsable de :

- la position de la balle ;
- la vitesse de la balle ;
- les collisions ;
- le score ;
- l'état de la partie ;
- la position des deux raquettes après réception des données réseau ;
- le démarrage et la fin de la partie.

Le deuxième téléphone ne doit pas décider indépendamment du résultat des collisions.

Cela évite les désynchronisations.

---

# 5. Communication réseau

Les deux téléphones doivent communiquer sur le réseau local.

Une architecture possible est :

```text
Player 1 / Host
      │
      │ WebSocket ou TCP local
      │
      ▼
Player 2 / Client
```

La communication doit être bidirectionnelle :

```text
Player 1 → position de sa raquette
Player 2 → position de sa raquette

Host → état de la balle
Host → score
Host → état de la partie
Host → événements de collision
```

Pour le premier prototype, privilégier une solution simple et fiable.

La couche réseau doit être isolée de la logique du jeu afin de pouvoir éventuellement remplacer plus tard le transport local par un serveur Internet.

---

# 6. Découverte des parties

Un joueur doit pouvoir créer une partie.

Exemple :

```text
PONG

Multiplayer

[ Create Game ]

[ Join Game ]
```

Après avoir créé la partie, le Host devient visible sur le réseau local.

Le deuxième joueur doit pouvoir découvrir la partie et la rejoindre.

Une solution possible est d'utiliser une découverte réseau locale basée sur :

- mDNS / Bonjour ;
- ou UDP broadcast/discovery.

L'objectif UX est de ne pas demander à l'utilisateur de connaître une adresse IP.

Exemple :

```text
Available Games

┌─────────────────────────────┐
│ Hans's Pong Game            │
│ 1 / 2 players               │
│                             │
│             [ JOIN ]        │
└─────────────────────────────┘
```

---

# 7. Hotspot / Wi-Fi

Les joueurs n'ont pas besoin d'être connectés à Internet.

Exemple :

```text
📱 Player 1
   │
   │ Hotspot Wi-Fi
   │
   └───────────📱 Player 2
```

Le Player 1 peut créer un hotspot et le Player 2 s'y connecter.

Une fois sur le même réseau local, ils peuvent jouer.

Le PC du développeur n'intervient absolument pas.

---

# 8. Nouveau flux utilisateur

## Écran d'accueil

Le jeu existant peut conserver son écran d'accueil.

Ajouter une option :

```text
[ SOLO ]

[ MULTIPLAYER ]
```

ou une structure équivalente selon le design existant.

---

## Écran Multiplayer

Ajouter un écran permettant de choisir :

```text
MULTIPLAYER

[ CREATE GAME ]

[ JOIN GAME ]
```

---

# 9. Flux "Create Game"

Le joueur 1 sélectionne :

```text
CREATE GAME
```

Le téléphone :

1. démarre le service réseau local ;
2. devient Host ;
3. crée une Game Room ;
4. publie/déclare la partie sur le réseau local ;
5. attend qu'un autre joueur rejoigne.

Écran possible :

```text
WAITING FOR PLAYER

Your game is visible to nearby players.

Players:
1 / 2

[ CANCEL ]
```

Lorsque le deuxième joueur rejoint :

```text
PLAYER 2 CONNECTED

[ START GAME ]
```

Selon l'expérience utilisateur souhaitée, le jeu peut aussi démarrer automatiquement.

---

# 10. Flux "Join Game"

Le joueur 2 sélectionne :

```text
JOIN GAME
```

L'application recherche les parties disponibles sur le réseau local.

Exemple :

```text
JOIN GAME

Available Games

┌─────────────────────────────┐
│ Hans's Game                 │
│ 1 / 2 players               │
│                             │
│ [ JOIN ]                    │
└─────────────────────────────┘

[ REFRESH ]
```

Après avoir rejoint :

```text
CONNECTED

Player 1: Ready
Player 2: Ready

[ READY ]
```

Lorsque les deux joueurs sont prêts, la partie commence.

---

# 11. Attribution des joueurs

La Room doit avoir deux rôles :

```text
Player 1 = Host
Player 2 = Client
```

Exemple :

```text
GameRoom
├── player1
├── player2
├── ball
├── score
└── gameState
```

Si le Host quitte la partie, le comportement doit être défini proprement.

Pour la première version, il est acceptable de terminer la partie et demander aux joueurs de recréer une partie.

Un système de migration du Host pourra être envisagé plus tard.

---

# 12. Accéléromètre

La mécanique existante avec l'accéléromètre doit être conservée.

Chaque téléphone contrôle sa propre raquette.

```text
Téléphone
   ↓
Accéléromètre
   ↓
position de la raquette
   ↓
Network
```

Player 1 :

```text
Accelerometer
      ↓
Paddle 1 Y
      ↓
Host Game Engine
```

Player 2 :

```text
Accelerometer
      ↓
Paddle 2 Y
      ↓
Host
```

Le mouvement du joueur doit être envoyé au Host avec une fréquence raisonnable.

Il ne faut pas envoyer inutilement des centaines de messages par seconde.

---

# 13. Position de la balle

La balle doit être calculée par le **Host**.

Exemple d'état :

```dart
double ballX = 0.5;
double ballY = 0.5;

double velocityX = 0.01;
double velocityY = 0.005;
```

Le terrain peut être normalisé :

```text
X: 0.0 → 1.0
Y: 0.0 → 1.0
```

Le Host met à jour :

```text
ballX
ballY
velocityX
velocityY
```

À chaque frame/tick du moteur de jeu :

```text
ballX += velocityX
ballY += velocityY
```

Puis il vérifie :

- collision avec le haut ;
- collision avec le bas ;
- collision avec Player 1 ;
- collision avec Player 2 ;
- sortie du terrain ;
- changement de score.

---

# 14. Autorité du Host

Le Host est la source de vérité.

Exemple :

```text
                    HOST
                     │
             ┌───────┴────────┐
             │                │
         Game Engine      Network
             │                │
             │                │
       Ball / Collision       │
             │                │
             └───────┬────────┘
                     │
                   Player 2
```

Si la balle touche une raquette :

```text
Host detects collision
        ↓
velocityX *= -1
        ↓
Host sends new state
        ↓
Both phones update
```

Cela empêche les deux appareils de calculer des résultats différents.

---

# 15. Synchronisation

Le Host peut envoyer périodiquement l'état du jeu.

Exemple :

```json
{
  "type": "game_state",
  "ball": {
    "x": 0.63,
    "y": 0.41,
    "vx": 0.01,
    "vy": 0.005
  },
  "paddles": {
    "player1": 0.32,
    "player2": 0.67
  },
  "score": {
    "player1": 3,
    "player2": 2
  }
}
```

Pour réduire l'impression de saccade, le client peut utiliser :

- interpolation ;
- prédiction simple ;
- timestamps ;
- correction périodique par le Host.

Mais pour le premier prototype, commencer par une synchronisation simple et fiable.

---

# 16. État de la partie

Prévoir des états explicites :

```text
WAITING
↓
PLAYER_JOINED
↓
READY
↓
PLAYING
↓
PAUSED
↓
GAME_OVER
```

Cela évite de mélanger la logique réseau et la logique d'affichage.

---

# 17. Fin de partie

Lorsqu'un joueur atteint la condition de victoire :

```text
GAME OVER

Player 1 Wins!

[ PLAY AGAIN ]

[ EXIT ]
```

Les deux téléphones doivent recevoir le même résultat.

Le Host est responsable de déterminer le gagnant.

---

# 18. Déconnexion

Prévoir les cas suivants :

### Player 2 quitte

Le Host reçoit la déconnexion.

Afficher :

```text
PLAYER 2 DISCONNECTED

Waiting for another player...
```

ou retourner au menu selon le comportement choisi.

### Host quitte

Pour la première version :

```text
GAME ENDED

Host disconnected.

[ BACK TO MENU ]
```

Une migration automatique du Host n'est pas nécessaire dans la première version.

---

# 19. Architecture logicielle recommandée

Ne pas mélanger directement :

- UI ;
- accélèromètre ;
- physique ;
- réseau ;
- gestion de Room.

Séparer les responsabilités.

Exemple conceptuel :

```text
lib/
├── core/
│   ├── networking/
│   ├── game/
│   └── constants/
│
├── features/
│   ├── home/
│   ├── multiplayer/
│   │   ├── create_game/
│   │   ├── join_game/
│   │   └── lobby/
│   │
│   └── pong/
│
├── services/
│   ├── accelerometer_service.dart
│   ├── local_network_service.dart
│   └── game_network_service.dart
│
└── models/
    ├── game_state.dart
    ├── player.dart
    └── game_room.dart
```

Cette structure est indicative et doit être adaptée à l'architecture déjà présente dans le projet.

---

# 20. Important : ne pas casser le mode Solo

Le mode Solo doit continuer à fonctionner.

L'objectif est :

```text
              PONG
                │
        ┌───────┴────────┐
        │                │
       SOLO         MULTIPLAYER
        │                │
   Game Engine      Local Network
                         │
                  Host / Client
```

La logique commune du jeu doit idéalement être réutilisable.

Par exemple :

```text
PongGameEngine
     │
     ├── Solo Mode
     │
     └── Multiplayer Host
```

et le Client Multiplayer peut utiliser le même système d'affichage du Pong tout en recevant l'état réseau.

---

# 21. FastAPI : rôle futur

FastAPI n'est **pas nécessaire pour le mode local**.

Cependant, l'architecture doit être conçue pour pouvoir ajouter plus tard un mode :

```text
ONLINE MULTIPLAYER
```

Dans ce futur mode :

```text
📱 Player 1
      │
      │ Internet
      ▼
☁️ FastAPI / WebSocket
      ▲
      │ Internet
      │
📱 Player 2
```

Le backend FastAPI pourrait alors gérer :

- matchmaking ;
- rooms ;
- présence ;
- parties en ligne ;
- authentification ;
- statistiques ;
- classement.

Mais cette étape est secondaire.

---

# 22. Architecture cible à long terme

Le projet pourrait finalement proposer :

```text
                    PONG
                     │
             ┌───────┴────────┐
             │                │
           SOLO          MULTIPLAYER
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  LOCAL               ONLINE
                    │                   │
                Wi-Fi LAN           Internet
                    │                   │
              Phone Host          Cloud Server
                    │                   │
                Phone Client       FastAPI
```

---

# 23. Plan d'implémentation recommandé

## Phase 1 — Refactor du jeu existant

- Identifier la logique actuelle du Pong.
- Séparer le Game Engine de l'UI si ce n'est pas déjà fait.
- Identifier la logique de la balle.
- Identifier la logique des raquettes.
- Identifier la gestion du score.
- Conserver l'accéléromètre existant.

## Phase 2 — Modèle Game State

Créer un modèle central représentant :

```text
GameState
├── ball
├── player1
├── player2
├── score
└── status
```

## Phase 3 — Communication locale

Implémenter :

- connexion locale ;
- serveur/Host sur le téléphone ;
- Client sur le deuxième téléphone ;
- messages réseau ;
- connexion/déconnexion.

## Phase 4 — Room

Ajouter :

- Create Game ;
- Join Game ;
- découverte des parties ;
- lobby ;
- Ready ;
- Start Game.

## Phase 5 — Synchronisation du Pong

- synchroniser les raquettes ;
- faire calculer la balle par le Host ;
- synchroniser la balle ;
- synchroniser les collisions ;
- synchroniser le score.

## Phase 6 — UX

Ajouter :

- écran d'attente ;
- joueur connecté ;
- déconnexion ;
- Game Over ;
- Play Again ;
- messages d'erreur réseau.

## Phase 7 — Optimisation

Après avoir obtenu un prototype fonctionnel :

- réduire la quantité de données envoyées ;
- améliorer la fréquence des updates ;
- interpolation ;
- correction de désynchronisation ;
- gestion des pertes de connexion.

## Phase 8 — Online Multiplayer

Seulement après avoir stabilisé le mode local :

- FastAPI ;
- WebSocket ;
- serveur cloud/VPS ;
- rooms online ;
- matchmaking ;
- authentification si nécessaire.

---

# 24. Règles techniques importantes

1. **Ne pas réécrire inutilement le jeu solo existant.**
2. **Le Host est l'autorité de la partie en multiplayer local.**
3. **La balle est calculée par le Host.**
4. **Les joueurs envoient principalement leur position de raquette.**
5. **Le score est déterminé par le Host.**
6. **Les deux téléphones doivent afficher le même Game State.**
7. **Le réseau doit être isolé dans une couche dédiée.**
8. **La logique du jeu doit être indépendante de l'interface.**
9. **Le mode Solo doit continuer à fonctionner.**
10. **L'architecture doit permettre d'ajouter un mode Online plus tard.**
11. **Ne pas introduire FastAPI dans le mode local simplement parce que le projet utilise Python/FastAPI ailleurs.**
12. **Commencer par un prototype à deux joueurs avant d'ajouter des fonctionnalités avancées.**

---

# 25. Résultat attendu du premier MVP Multiplayer

Le premier MVP est considéré comme réussi lorsque :

1. Deux téléphones Android ont l'application.
2. Ils sont sur le même réseau Wi-Fi local.
3. Le téléphone A crée une partie.
4. Le téléphone B détecte la partie.
5. B rejoint A.
6. Les deux joueurs arrivent dans le lobby.
7. La partie démarre.
8. Chaque joueur contrôle sa raquette avec l'accéléromètre.
9. Le Host calcule la balle.
10. Les deux joueurs voient la même balle.
11. Les collisions fonctionnent.
12. Le score est synchronisé.
13. Le gagnant est identique sur les deux téléphones.
14. Un joueur peut quitter proprement la partie.
15. Le mode Solo existant continue de fonctionner.

---

# 26. Vision du projet

Le but n'est pas seulement d'ajouter un bouton "Multiplayer".

Le projet doit évoluer vers une architecture de jeu capable de fonctionner avec plusieurs modes de transport :

```text
             Pong Game Engine
                    │
        ┌───────────┴───────────┐
        │                       │
      Local                  Online
        │                       │
   Local Network          WebSocket
        │                       │
 Phone ↔ Phone              FastAPI
```

La priorité immédiate est cependant :

> **Construire un multiplayer local fiable à deux joueurs, sans Internet et sans PC, en conservant l'accéléromètre et la logique actuelle du Pong.**
