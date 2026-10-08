# Roadmap — Pong Game

Checklist de suivi du projet. Chaque tâche est cochée dès qu'elle est terminée et vérifiée.

Légende : `[ ]` à faire · `[~]` en cours · `[x]` terminé

Ordre de travail : la phase 1 (solo et corrections) est terminée avant de commencer la phase 2 (multijoueur local). La phase 3 (en ligne) n'est pas planifiée en détail.

Décisions déjà prises :
- Le jeu reste en **vertical** : raquettes en haut et en bas, coordonnées -1 → 1.
- Duel : le premier à **5 points** gagne.
- Duel : chaque joueur appuie sur **Prêt** avant le démarrage.
- Tous les textes restent en **français**.
- **Pas de pause** en duel pour le MVP.

---

## Phase 1 — Mode solo et corrections

### 1.1 Corrections de bugs

Code terminé et relu ; validation sur téléphone prévue avec le test de fin de phase 1.3.

- [x] **Son d'accueil manquant** : l'appel à `welcome.mp3` (fichier absent) est retiré
- [x] **Halo permanent sur la balle** : le halo ne s'affiche plus qu'avant le démarrage
- [x] **Raquette qui bouge hors partie** : accéléromètre ignoré avant le démarrage, en pause et après la défaite
- [x] **Pseudo non modifiable** : lien « Modifier » à côté de « Bonjour <pseudo> »
- [x] **Musique d'accueil** : elle reprend au retour du jeu
- [x] **Meilleur score de l'accueil** : rafraîchi au retour d'une partie
- [x] **Fuites audio** : lecteurs `letsgo` et `shoot` libérés dans `dispose()`
- [x] **`setState` après fermeture de l'écran** : minuteur du halo de score protégé par `mounted`
- [x] **Fin de partie** : `resetgame()` appelé une seule fois, `onPopInvoked` déprécié retiré
- [x] **Orientation** : app verrouillée en portrait
- [x] **Score nul au classement** : une partie à 0 point n'est plus enregistrée
- [x] **Plantage audio** (`IllegalStateException` dans `MediaPlayer.getPlaybackParams`, vu une fois en release) : tous les sons passent par `GameSound` (`lib/game_sound.dart`), qui charge chaque son une fois et envoie les commandes une par une. Disparition du plantage à confirmer sur téléphone
- [x] **Erreur du capteur au démarrage** (`MissingPluginException … setAccelerationSamplingPeriod`) : `sensors_plus` passé en 4.0.2. À confirmer dans les journaux du téléphone

### 1.2 Nettoyage

- [x] Supprimer `_losePlayer`, `_counter` et le code commenté (`ball.dart`, `brouillon.dart` supprimé)
- [x] Corriger les avertissements de `flutter analyze` : 129 remarques dont 22 avertissements au départ, 0 avertissement et 18 infos à la fin (noms de classes et `withOpacity`, laissés volontairement)
- [x] Remplacer le test par défaut `widget_test.dart` par les tests du moteur
- [x] Pseudo : refuser un pseudo fait d'espaces (`trim`)
- [x] Accueil : empêcher le double tap sur « S U I V A N T » d'ouvrir deux parties
- [x] Accueil : protéger par `mounted` le `setState` de la secousse du champ
- [x] Fins de ligne : `.gitattributes` ajouté
- Sons inutilisés (`winter`, `chiptune`, `reprendre`, `win1`, `lose1`, `lose2`, `lose3`) : conservés pour l'instant, à utiliser ou supprimer en 1.4

### 1.3 Moteur de jeu séparé de l'écran

Nécessaire pour tester le jeu et pour le multijoueur. Le comportement du solo ne doit pas changer.

- [x] Extraire la logique dans `lib/game/pong_engine.dart`
- [x] Brancher `hompage.dart` sur le moteur
- [x] Boucle de jeu à pas fixe (`stepsPerSecond` pas de moteur par seconde), un seul rafraîchissement par image. Les constantes de vitesse n'ont pas changé
- [x] Tests unitaires du moteur : 30 tests (rebonds, score, accélération, défaite, IA)
- [ ] **Test du solo sur un vrai téléphone par le propriétaire, dans les trois difficultés — en attente d'approbation**
  - [~] Vitesse du jeu : réglage au ressenti avec le propriétaire, actuellement 450 pas par seconde (l'ancien code en faisait environ 700 en release sur SM-A135F, jugé trop rapide ; 500 jugé presque bon)

### 1.3 bis Contrôle de la raquette indépendant du téléphone

À faire après l'approbation du test solo de la 1.3 et avant la phase 2 (le duel exige la même raquette sur deux téléphones). Aujourd'hui la raquette avance à chaque événement du capteur, donc sa vitesse dépend de la cadence du capteur de chaque téléphone.

- [x] Mesurer sur le SM-A135F la cadence réelle de l'accéléromètre : **6 événements par seconde**. La raquette avance donc par 6 sauts par seconde, à 1,18 × sin(inclinaison) unité/s (0,59 unité/s à 30°, 1,18 au maximum)
- [x] `sensors_plus` mis à jour en 4.0.2 pour lire le capteur à 50 Hz ; la compilation Android en release passe sans toucher aux outils de compilation
- [x] Le capteur mémorise l'inclinaison (`lib/game/tilt_control.dart`), le moteur déplace la raquette à chaque pas (`playerSpeed`), avec tests (59 tests au total)
- [x] Inclinaison normalisée, lissage de 50 ms, zone morte progressive d'environ 3°, vitesse maximale
- [x] Première version réglée sur la vitesse actuelle de la raquette (1,18 unité/s au maximum)
- [ ] **Test sur téléphone par le propriétaire, puis réglage de la raquette au ressenti — en attente**

### 1.5 Redesign du mode solo

Maquettes : `maquette/Redesign app PONG mobile/` (système de design, écrans solo, multijoueur, parcours).

- [x] Système de design partagé (`lib/ui/`) : palette, police Archivo intégrée, composants
- [x] Chargement, accueil, classement, statistiques, aide, conformes aux maquettes (vérifiés sur téléphone)
- [x] Écran de jeu, pause, fin de partie, conformes aux maquettes (vérifiés sur téléphone)
- [x] Écran Réglages : musique, effets sonores, vibration, sensibilité de la raquette (5 crans), pseudo
- [ ] Installer la version finale sur le téléphone (bloqué : disque C: plein) et vérifier l'écran Réglages sur l'appareil
- [ ] **Test du mode solo redessiné par le propriétaire — en attente**

### 1.4 Améliorations du solo

- [ ] Musique de fond pendant la partie
- [ ] Effets visuels à l'impact raquette/balle
- [ ] Traînée derrière la balle
- [ ] Niveaux progressifs avec effets visuels par palier
- [ ] Power-ups (raquette plus large, balle ralentie…)
- [ ] Mode multi-balle

---

## Phase 2 — Multijoueur local

Référence : `pong_multiplayer_spec.md`. Deux téléphones sur le même Wi-Fi ou hotspot, sans Internet. Le téléphone qui crée la partie (Host) fait autorité.

### 2.1 Modèles et règles du duel

- [ ] Modèles `GameState`, `Player`, `GameRoom`
- [ ] États de partie : attente, joueur connecté, prêt, en jeu, terminé
- [ ] Mode duel dans le moteur : la raquette du haut est pilotée par le joueur 2
- [ ] Largeur de raquette indépendante de la taille de l'écran (identique sur les deux téléphones)
- [ ] Score par manche, victoire à 5 points, remise en jeu après chaque point
- [ ] Tests unitaires du mode duel

### 2.2 Couche réseau

Isolée du moteur, pour pouvoir la remplacer plus tard par un serveur en ligne.

- [ ] Interface de transport commune (envoyer, recevoir, connexion, déconnexion)
- [ ] Format des messages JSON : `join`, `ready`, `start`, `paddle`, `game_state`, `game_over`, `leave`
- [ ] Serveur WebSocket côté Host (`dart:io`)
- [ ] Client WebSocket côté joueur 2
- [ ] Permissions Android : `INTERNET` dans le manifeste principal, état et multicast Wi-Fi
- [ ] Test de connexion entre deux téléphones

### 2.3 Découverte des parties

- [ ] Annonce de la partie par broadcast UDP côté Host
- [ ] Écoute et liste des parties côté Client
- [ ] Retrait d'une partie qui n'est plus annoncée
- [ ] Test sur Wi-Fi classique et sur hotspot

### 2.4 Écrans et parcours

- [ ] Bouton « Multijoueur » sur l'écran d'accueil
- [ ] Écran menu multijoueur (Créer / Rejoindre)
- [ ] Écran liste des parties (Rejoindre, Actualiser)
- [ ] Écran salon (attente, joueur connecté, Prêt, Annuler)
- [ ] Écran de jeu duel (deux scores, pas de pause)
- [ ] Dialogue de fin de partie (gagnant, Rejouer, Quitter)
- [ ] Dialogue de déconnexion et messages d'erreur réseau

### 2.5 Synchronisation

- [ ] Le Host fait tourner le moteur et envoie l'état 30 fois par seconde
- [ ] Le Client envoie la position de sa raquette 30 fois par seconde
- [ ] Vue inversée chez le Client : chacun voit sa raquette en bas
- [ ] Sons et vibrations déclenchés par les événements du Host
- [ ] Même score et même gagnant sur les deux téléphones
- [ ] Rejouer sans recréer la partie

### 2.6 Déconnexions

- [ ] Le joueur 2 quitte : le Host retourne au salon
- [ ] Le Host quitte : le Client voit « Partie terminée » et retourne au menu
- [ ] Perte de Wi-Fi ou app mise en arrière-plan

### 2.7 Validation du MVP

- [ ] Les 15 critères de la section 25 de la spec passent sur deux téléphones Android
- [ ] Le mode solo fonctionne toujours

### 2.8 Optimisation (après le MVP)

- [ ] Interpolation de la balle chez le Client
- [ ] Réduction de la taille et de la fréquence des messages
- [ ] Correction des désynchronisations

---

## Phase 3 — Multijoueur en ligne (plus tard)

- [ ] À planifier une fois la phase 2 stabilisée : serveur FastAPI/WebSocket, salons en ligne, matchmaking, authentification

---

## Nouveaux écrans

| Écran | Phase | Rôle |
|---|---|---|
| Menu multijoueur | 2.4 | Choisir entre « Créer une partie » et « Rejoindre une partie » |
| Liste des parties | 2.4 | Parties trouvées sur le réseau, boutons Rejoindre et Actualiser |
| Salon | 2.4 | Attente du second joueur, statut Prêt de chacun, Annuler |
| Jeu duel | 2.4 | Partie à deux : scores des deux joueurs, sans pause |

Ajouts sur des écrans existants, sans nouvel écran :
- Accueil : bouton « Multijoueur » et bouton « Modifier » le pseudo
- Dialogues : fin de partie en duel, déconnexion
