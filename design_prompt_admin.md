# Tilto — maquette de l'administration du site

## Ce que je te demande

Tu as dessiné le site de présentation de **Tilto** (planches « Tilto Site » et « Tilto Site v2 »), un jeu mobile du studio **Nexora**. Le site est en ligne sur https://tilto.fun ; il a depuis reçu une marge horizontale globale, un **mode clair et un mode sombre**, et des espacements plus serrés.

Il a une **administration** (`/admin`), utilisée par une seule personne, le propriétaire, pour modifier le contenu du site sans toucher au code. Elle fonctionne, mais elle n'a aucun design : des formulaires bruts. Je te demande **la maquette complète de cette administration**, écran par écran, avec tous les champs et toutes les valeurs listés plus bas.

## La règle qui vaut pour tout : rien de générique

Comme pour l'app et le site :
- **pas d'icônes partout** : une icône seulement quand elle aide vraiment (par exemple déplacer, supprimer), jamais en décoration devant chaque titre ou chaque champ ;
- **pas de tableau de bord « SaaS »** avec des cartes de statistiques à icônes, des graphiques ou des pourcentages inventés ;
- **pas de pastilles, badges et dégradés décoratifs** ;
- à la place : une interface d'édition **sobre, dense et claire**, où le contenu à modifier est au premier plan, avec la typographie et l'espace comme outils principaux.

## Identité et contraintes

- Même identité que le site : fond sombre `#0B0B10`, surfaces `#15151C` / `#1E1E28`, bordures `#2A2A36`, texte `#F2F2F5`, texte secondaire `#9E9EAB`, rose `#E91E63` (boutons pleins en `#D81B60` pour le contraste), police **Archivo**.
- Propose **aussi le mode clair** (fond `#F6F6F9`, texte `#14141B`, liens `#C2185B`), avec le même bouton de bascule que le site.
- Un seul bouton rose plein par écran : l'action principale (« Enregistrer », « Déposer »…).
- Le site est codé en **HTML et CSS simples** (rendu côté serveur, un peu de JavaScript, aucun framework) : formulaires classiques, pas d'effets qui exigent une application JavaScript.
- Montre chaque écran **sur ordinateur (1440 px)** et les écrans principaux **sur mobile (360 px)** : le propriétaire doit pouvoir déposer un APK ou corriger un texte depuis son téléphone.
- Textes de l'interface en **français**, tutoiement. Zones tactiles d'au moins 44 px.
- Prévois partout les **messages de retour** (bandeau en haut du contenu) : succès (« Textes enregistrés. »), erreur (« Le nom du studio est obligatoire. », « Ce fichier n'est pas une image acceptée (PNG, JPEG, WebP, GIF). ») et les erreurs de champ.
- Les actions destructrices (supprimer) demandent une confirmation.

## Navigation

Menu permanent (barre latérale sur ordinateur, menu repliable sur mobile) :
- Tableau de bord
- Messages (avec le nombre de non-lus)
- Contenu de la page : Textes, Fiche technique, Arguments, Solo / Duel, Comment jouer, Barème, Captures, FAQ, Installation
- APK et notes de version
- Studio
- Pages légales : Confidentialité, Mentions légales
- Voir le site (s'ouvre dans un nouvel onglet)
- Se déconnecter

Le nom du jeu et du studio peuvent rappeler où l'on est (« Tilto · Nexora »).

## Écrans et champs

### 1. Connexion
- Un seul champ : **mot de passe** (pas d'identifiant, il n'y a qu'un administrateur).
- Bouton « Se connecter ».
- États : erreur « Mot de passe incorrect. » ; blocage après 5 essais en 15 minutes : « Trop de tentatives. Réessaie dans quelques minutes. »
- Rappeler discrètement que c'est l'administration de Tilto ; pas de lien « mot de passe oublié » (il se change sur le serveur).

### 2. Tableau de bord
Une vue d'ensemble de **l'état du site**, pas des statistiques :
- **Messages non lus** du formulaire de contact (nombre, et les 3 derniers : nom, sujet, début du message).
- **Mentions légales incomplètes** : alerte tant que les champs obligatoires sont vides.
- **Version proposée au téléchargement** : numéro (ex. 2.0.0), taille (ex. 18 Mo), date de dépôt ; ou « aucune » avec un lien pour en déposer une.
- **Lien Play Store** : l'adresse, ou « non renseigné ».
- **Adresse de contact** : l'adresse, ou « non renseignée ».
- **Captures d'écran** : combien en ont une image (ex. « 1 sur 3 avec image »).
- Un rappel de **ce qu'il reste à faire** pour que le site soit complet (par exemple : déposer l'APK, ajouter les images des captures, renseigner le contact), qui disparaît quand tout est rempli.
- Accès direct à chaque section, et lien « Voir le site ».

### 3. Textes
Un formulaire avec ces champs (libellé, longueur maximale, type) :
| Champ | Max | Type | Exemple |
|---|---|---|---|
| Nom du jeu (titre du haut de page) | 60 | ligne | Tilto |
| Accroche du haut de page | 300 | zone de texte | Le Pong qu'on joue en inclinant son téléphone. Seul contre l'ordinateur, ou à deux sur le même Wi-Fi. |
| Mention sous les boutons | 80 | ligne | Gratuit · Android |
| Titre du bloc de téléchargement | 80 | ligne | Télécharge Tilto |
| Phrase du bloc de téléchargement | 300 | zone de texte | Pour téléphones Android. L'APK s'installe sans le Play Store. |
| Lien Play Store (vide = bouton masqué) | 500 | URL | https://play.google.com/store/apps/details?id=… |
| Adresse de contact (vide = lien masqué) | 200 | e-mail | contact@tilto.fun |
Bouton « Enregistrer ». Montrer un compteur de caractères sur les champs longs, et l'erreur « Adresse e-mail invalide. ».

### 3 bis. Fiche technique (haut de page)
Lignes ordonnées libellé / valeur : MODES · Solo · Duel ; JOUEURS · 1 ou 2 ; INTERNET · Jamais requis ; ANDROID · 5.0 et plus ; PRIX · Gratuit. Plus le sur-titre du haut de page (« PONG VERTICAL · ANDROID · SOLO ET DUEL LOCAL »), le texte de présentation long et sa version courte pour mobile, et la légende de la démo. Actions : ajouter, modifier, monter, descendre, supprimer.

### 4. Arguments (section « Le jeu » du site)
Une **liste ordonnée** d'éléments ; le site en affiche 4 avec une démonstration dessinée chacun. Pour chaque élément :
| Champ | Max | Exemple |
|---|---|---|
| Sur-titre | 40 | INCLINE |
| Titre | 120 (obligatoire) | Pas de bouton. Tu penches, la raquette suit. |
| Texte | 1000 | Tiens ton téléphone à deux mains et incline-le à gauche ou à droite. Rien à l'écran ne cache la balle. |
Chaque argument a aussi un **texte court pour mobile** (facultatif) et une liste de **caractéristiques** ordonnées libellé / valeur (ex. « Format · Premier à 5 points », « Réseau · Même Wi-Fi ou hotspot »), éditables dans l'écran de l'argument. Plus le sur-titre, le titre et l'introduction de la section (« CE QUI CHANGE DU PONG CLASSIQUE », « Quatre idées, poussées jusqu'au bout. »).
Actions par élément : modifier, monter, descendre, supprimer. Action générale : ajouter un argument. Contenu actuel : INCLINE, À DEUX, SENSIBILITÉ, RECORDS. Indique que les 4 premiers ont une illustration sur le site, et qu'un 5ᵉ s'affiche en texte seul.

### 5. Comment jouer
Même principe, liste ordonnée d'étapes :
| Champ | Max | Exemple |
|---|---|---|
| Titre | 120 (obligatoire) | Prends ton téléphone à deux mains. |
| Précision (facultatif) | 1000 | En portrait, l'écran face à toi. |
Actions : ajouter, modifier, monter, descendre, supprimer. Contenu actuel : 3 étapes.

### 5 bis. Solo / Duel (comparatif)
Lignes ordonnées : critère, valeur Solo, valeur Duel (ex. « Pause · Oui, avec musique · Non, le duel ne s'arrête pas »). Actions : ajouter, modifier, monter, descendre, supprimer.

### 5 ter. Barème en solo
Lignes ordonnées libellé / valeur : « Chaque renvoi · +50 », « L'ordinateur rate la balle · +100 », « La balle accélère · tous les 4 renvois ».

### 6. Captures
Liste ordonnée de captures d'écran de l'app (format portrait, idéalement 1080 × 2400) :
- **Image** (PNG, JPEG, WebP ou GIF, 5 Mo maximum) : aperçu dans un cadre de téléphone, ou emplacement vide si pas encore d'image ;
- **Légende** (ex. « L'accueil », « En solo », « En duel », « Fin du duel ») et **description** (une ou deux phrases) ;
- actions : ajouter une capture (image + légende), remplacer l'image, modifier la légende, monter, descendre, supprimer.
- Montre l'état « aucune image encore » (c'est l'état actuel des 3 captures) et l'état avec images.

### 6 bis. FAQ
Questions / réponses ordonnées. Pour chacune : question, réponse, réponse courte pour mobile (facultative), **ancre** (identifiant de lien, ex. `duel-connexion`, générée depuis la question si vide, unique) et libellé facultatif pour le lien dans le pied de page (rubrique Aide). Actions : ajouter, modifier, monter, descendre, supprimer.

### 6 ter. Installation de l'APK
Étapes ordonnées (titre, précision) et la note sur le Play Store.

### 7. APK
- **Déposer une nouvelle version** : fichier APK (200 Mo maximum, vérifié), numéro de version (ex. 2.0.1), case « la proposer tout de suite au téléchargement ». Montre l'envoi en cours (un APK fait 20 à 30 Mo) et les erreurs : « Ce fichier n'est pas un APK valide. », « La version 2.0.1 existe déjà. », « Numéro de version invalide (exemple : 1.2.0). ».
- **Notes de version** pour chaque APK : date de sortie et une nouveauté par ligne ; celles de la version proposée s'affichent sur le site (« Nouveautés 1.0.0 »).
- **Historique des versions** : version, taille, date de dépôt, empreinte SHA-256 (abrégée, copiable), statut « proposée au téléchargement » pour une seule d'entre elles ; actions : « Proposer celle-ci », « Supprimer » (impossible pour la version proposée).
- Le lien public de téléchargement (`https://tilto.fun/telecharger`) et la mention qui s'affiche sur le site (« Version 2.0.0 · 18 Mo »).

### 8. Studio
- **Nom du studio** (60, obligatoire) : Nexora.
- **Logo du studio** (PNG, JPEG, WebP, GIF ou SVG, 5 Mo maximum) : aperçu du logo actuel **sur fond sombre et sur fond clair** (le site a les deux thèmes), remplacer, retirer.
- Rappel de l'endroit où ils apparaissent : pied de page du site (« Un jeu de Nexora · © 2026 »).

### 8 bis. Mentions légales
Champs : nom ou raison sociale de l'éditeur, forme juridique, numéro d'immatriculation (facultatif), adresse, e-mail, téléphone (facultatif), directeur de la publication ; hébergeur : nom (pré-rempli « Contabo GmbH »), adresse, téléphone ; texte libre complémentaire. Montrer quels champs obligatoires manquent.

### 8 ter. Messages (formulaire de contact)
- **Liste** : non lus en premier ou mis en évidence ; pour chacun : nom (ou « Sans nom »), e-mail, sujet (Question, Problème technique, Suggestion, Autre), date, début du message.
- **Lecture d'un message** : message complet, bouton « Répondre » (ouvre la messagerie avec l'adresse), « Marquer comme lu / non lu », « Supprimer » (avec confirmation).
- État « aucun message ».

### 9. Confidentialité
- **Date de dernière mise à jour** (sélecteur de date).
- **Texte de la politique** : grande zone d'édition, avec une syntaxe simple : paragraphes séparés par une ligne vide, intertitres commençant par « ## ». Prévois un **aperçu** à côté (ordinateur) ou en onglet (mobile), dans le style de la page publique.
- Bouton « Enregistrer ».

## Livrables

1. Une planche avec tous les écrans sur ordinateur (1440 px), en mode sombre.
2. Les mêmes en mode clair, au moins le tableau de bord, Textes, Captures et APK.
3. Les écrans principaux sur mobile (360 px) : connexion, tableau de bord, menu ouvert, Messages et lecture d'un message, Textes, APK (dépôt), Captures.
4. Les états : messages de succès et d'erreur, liste vide, capture sans image, aucun APK, envoi en cours, confirmation de suppression.
5. Quelques phrases qui expliquent tes choix.
