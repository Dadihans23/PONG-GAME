# Redesign de l'app mobile « PONG »

## Ce que je te demande

Des maquettes haute fidélité pour le redesign d'un jeu de Pong mobile qui existe déjà et que des joueurs utilisent. Je veux une app plus soignée et plus cohérente, **sans perdre son identité actuelle** : thème sombre, accent rose néon, titres en lettres espacées. C'est une évolution, pas une refonte de zéro.

Les maquettes doivent couvrir :
1. les **écrans existants**, redessinés ;
2. les **nouveaux écrans** du mode multijoueur local, qui arrive bientôt ;
3. un **petit système de design** (couleurs, typographie, boutons, cartes, dialogues) qui servira aussi aux écrans futurs.

Les maquettes seront ensuite développées en Flutter avec les widgets standards : évite les effets impossibles à reproduire simplement (3D, illustrations complexes, vidéos).

## Le jeu

- Pong **vertical**, en **portrait uniquement** : la raquette du joueur est en bas, celle de l'adversaire en haut, la balle va de haut en bas.
- On déplace sa raquette en **inclinant le téléphone** (accéléromètre). Pendant une partie, le joueur tient son téléphone à deux mains et l'incline : **aucun bouton ne doit être nécessaire en jeu**, à part la pause, et rien ne doit masquer la balle ni les raquettes.
- Mode solo contre une IA, trois difficultés : Facile, Normal, Difficile.
- Score : 50 points par renvoi, 100 points quand l'adversaire rate. La balle accélère tous les 4 renvois. La partie s'arrête quand la balle passe derrière le joueur.
- Le jeu a des sons et une vibration à chaque renvoi : l'interface peut s'appuyer sur ces moments forts (renvoi, nouveau record, défaite).
- **Tous les textes sont en français.**
- Cible : téléphones Android, y compris d'entrée de gamme (petit écran, 60 Hz). Concevoir pour environ 360 × 800.

## Objectifs du redesign

1. **Garder l'identité** : fond très sombre, rose néon pour l'action principale, halos lumineux, titres en majuscules espacées (« P O N G »).
2. **Unifier** : aujourd'hui chaque écran a été fait à part. Je veux une seule grille, une seule famille de boutons, de cartes et de titres.
3. **Clarifier la hiérarchie** : une seule action principale évidente par écran, les actions secondaires en retrait.
4. **Rendre l'écran de jeu plus lisible et plus vivant**, sans le surcharger.
5. **Préparer l'arrivée du multijoueur et des futures fonctionnalités** (power-ups, niveaux, multi-balle) dans la navigation et le système de design.

## Identité visuelle actuelle (à faire évoluer, pas à remplacer)

| Élément | Aujourd'hui |
|---|---|
| Fond des écrans | Noir presque pur (`#000000` à ~12 % d'opacité sur noir, donc quasi noir) |
| Fond du chargement | Noir pur `#000000` |
| Cartes | Gris très foncé `#212121`, semi-transparent (60 %), coins arrondis 10 à 12 px |
| Action principale | Rose `#E91E63` avec un halo rose diffus autour (ombre large, floue) |
| Bouton non sélectionné | Gris foncé `#212121`, texte gris |
| Texte principal | Blanc |
| Texte secondaire | Gris `#9E9E9E` |
| Titres | Majuscules espacées par des espaces : « P O N G », « C L A S S E M E N T », « S T A T I S T I Q U E S », « A I D E », poids extra-gras, gris |
| Raquette du joueur | Bleu `#2196F3`, rectangle 80 × 15 px aux coins arrondis |
| Raquette adverse | Vert `#4CAF50`, même forme |
| Balle | Cercle blanc de 20 px, avec un halo pulsé avant le début de la partie |
| Bouton « Aide » | Turquoise `#009688` |
| Bouton « Statistiques » | Violet `#673AB7` |
| Bouton « Rejouer » | Bleu `#2962FF` |
| Podium du classement | Or `#FFD700`, argent `#C0C0C0`, bronze `#CD7F32` |
| Couleurs des statistiques | Bleu `#448AFF` (parties), rose `#E91E63` (temps), orange `#FF9800` (série) |

Les couleurs secondaires (turquoise, violet, bleu vif) ont été ajoutées au fil de l'eau : tu peux les rationaliser en une palette cohérente, tant que le rose reste l'accent principal et que le bleu (joueur) et le vert (adversaire) restent reconnaissables en jeu.

## Écrans existants à redessiner

### 1. Écran de chargement
Noir, titre « P O N G » en blanc, barre de progression rose avec pourcentage (0 à 100 %), texte « Chargement... ». Dure environ 6 secondes, avec un son.

### 2. Accueil
C'est le hub de l'app. Contenu actuel, de haut en bas :
- titre « P O N G » ;
- **premier lancement** : champ « Entrez votre pseudo » (il tremble et passe en rouge s'il est vide) ;
- **lancements suivants** : « Bonjour <pseudo> » avec un lien rose « Modifier » qui réaffiche le champ ;
- « Choisis le niveau de difficulté » : trois boutons empilés Facile / Normal / Difficile (le sélectionné est rose avec halo, les autres gris foncé) ;
- bouton principal rose « S U I V A N T » (lance la partie) ;
- « Meilleur score : <n> » ;
- bouton turquoise « A I D E ».

**À ajouter** : l'entrée vers le mode **Multijoueur**. Je veux que l'accueil propose clairement deux modes, **Solo** et **Multijoueur**, la difficulté ne concernant que le Solo. Le classement et les statistiques devraient aussi être accessibles depuis l'accueil (aujourd'hui on ne les atteint qu'après une défaite). Propose la structure la plus claire.

### 3. Écran de jeu (solo)
- Fond quasi noir, raquette adverse verte en haut, raquette du joueur bleue en bas, balle blanche.
- **Avant le début** : texte « T A P E Z  L'É C R A N » au centre et balle avec halo pulsé. On démarre en tapant n'importe où.
- **En jeu** : « <pseudo> : <score> » sous le centre et « top score : <n> » au-dessus du centre, en gris, très espacés. Bouton pause (icône) en haut à droite, sur fond gris foncé semi-transparent.
- Retours au renvoi : vibration, son, et un effet lumineux est prévu sur le score.

Propose un écran plus lisible et plus vivant : terrain (ligne médiane ? bords ?), affichage du score, mise en valeur du nouveau record. Montre au moins les états **avant le début**, **en jeu**, et **nouveau record battu en cours de partie**.

### 4. Pause
Voile noir à 60 % sur le jeu, « PAUSE » en blanc, bouton rose « R E P R E N D R E ». Une musique joue pendant la pause. Tu peux ajouter « Quitter » en action secondaire.

### 5. Fin de partie (solo)
Aujourd'hui un petit dialogue **clair** (fond gris très pâle, qui jure avec le reste), « Vous avez eu <score> », et trois boutons : Rejouer (bleu), Classement (rose), Statistiques (violet). Redessine-le dans le thème sombre, avec le score mis en valeur, l'indication « Nouveau record ! » quand c'est le cas, et une action principale évidente (Rejouer).

### 6. Classement
Titre « C L A S S E M E N T », retour en haut à gauche. Top 10 local : rang (trophée or/argent/bronze pour le podium, numéro ensuite), pseudo, date (jj/mm/aaaa), score. Cartes gris foncé, bordure de la couleur du podium pour les 3 premiers. État vide : « Aucun score enregistré ».

### 7. Statistiques
Titre « S T A T I S T I Q U E S ». Trois cartes avec icône, libellé et grande valeur colorée : Parties jouées, Temps total de jeu (« 1h 12m 5s »), Meilleure série (« 23 renvois »). Prévois la place pour quelques statistiques de plus, notamment le multijoueur (victoires/défaites).

### 8. Aide
Titre « A I D E ». Cartes avec icône colorée, titre et texte : Contrôles (incliner le téléphone), Objectif, Points (50 / 100), Vitesse (accélère tous les 4 renvois), Pause. Une section « Multijoueur » s'ajoutera.

## Nouveaux écrans : multijoueur local

Principe : deux joueurs, deux téléphones sur le **même Wi-Fi ou le hotspot de l'un des deux**, **sans Internet**. Le joueur qui crée la partie est l'« hôte », l'autre la rejoint. Le jeu trouve les parties tout seul : **le joueur ne saisit jamais d'adresse IP**. Chaque joueur voit **sa propre raquette en bas** (bleue) et l'adversaire en haut. Duel en **5 points**, **pas de pause** en multijoueur.

### 9. Menu multijoueur
Deux choix : « Créer une partie » et « Rejoindre une partie ». Rappel discret de la condition : être sur le même Wi-Fi ou hotspot.

### 10. Rejoindre : liste des parties
Recherche en cours (animation), puis liste des parties trouvées : « Partie de <pseudo> », « 1 / 2 joueurs », bouton « Rejoindre ». Bouton « Actualiser ». États à montrer : **recherche**, **parties trouvées**, **aucune partie trouvée** (avec conseil : vérifier le Wi-Fi, demander à l'autre joueur de créer la partie).

### 11. Salon
Vu par l'hôte et par l'invité. Les deux joueurs (pseudo, statut « En attente » / « Prêt »), bouton principal « Prêt », action secondaire « Annuler » ou « Quitter ». La partie démarre quand les deux sont prêts (un compte à rebours 3-2-1 serait bienvenu). États : **en attente du second joueur** (hôte seul, « Votre partie est visible par les joueurs à proximité »), **joueur connecté**, **les deux prêts**.

### 12. Jeu en duel
Même terrain que le solo, mais avec le score des deux joueurs (ex. « 3 – 2 », premier à 5), les deux pseudos, pas de bouton pause. Un court moment « Point pour <pseudo> » après chaque point.

### 13. Fin du duel
« <pseudo> gagne ! » (variante « Victoire » / « Défaite » selon le téléphone), score final, actions « Rejouer » (principale) et « Quitter ». Indiquer quand on attend la réponse de l'autre joueur pour rejouer.

### 14. Déconnexion et erreurs réseau
Dialogues ou écrans : « L'autre joueur s'est déconnecté » (côté hôte : retour au salon), « L'hôte a quitté la partie » (côté invité : retour au menu), « Connexion impossible ». Textes simples, jamais de message technique.

## Écrans futurs à anticiper

Pas besoin de maquettes complètes, mais le système de design et la navigation doivent pouvoir les accueillir :
- **Power-ups** en jeu (raquette plus large, balle ralentie…) : une icône sur le terrain et un indicateur discret de bonus actif.
- **Niveaux progressifs** : annonce de passage de niveau en cours de partie, avec un effet visuel par palier.
- **Multi-balle** : plusieurs balles à l'écran.
- **Effets d'impact et traînée de balle**.
- Plus tard, un **multijoueur en ligne** (matchmaking) : l'accueil doit pouvoir accueillir ce troisième mode.
- Un écran **Réglages** (sensibilité de la raquette, son, vibration) est probable.

Si tu as le temps, une maquette de l'écran de jeu avec un power-up actif et une annonce de niveau m'aiderait.

## Contraintes

- Portrait, 360 × 800 environ, zones tactiles d'au moins 48 px.
- Lisibilité en mouvement : la balle et les raquettes doivent rester les éléments les plus visibles de l'écran de jeu ; les scores ne doivent pas être confondus avec la balle.
- Contrastes suffisants sur fond sombre.
- Textes courts, en français courant, qui disent au joueur quoi faire.
- Pas de dépendance à des visuels lourds : formes simples, dégradés et halos légers.

## Livrables attendus

1. Une planche **système de design** : palette (avec codes hex et rôle de chaque couleur), typographie (titres espacés, textes, chiffres du score), boutons (principal, secondaire, sélectionné, désactivé), cartes, champ de texte, dialogue, icônes.
2. Les **8 écrans existants** redessinés, avec leurs états.
3. Les **6 écrans multijoueur**, avec leurs états.
4. Une vue du **parcours** : chargement → accueil → solo ou multijoueur → jeu → fin de partie → classement / statistiques.
5. Pour chaque choix fort, une phrase qui l'explique.
