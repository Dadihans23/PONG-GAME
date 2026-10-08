# Système de design Pong (v2)

Code Flutter de la planche `maquette/Redesign app PONG mobile/Pong Design System.dc.html`.
Un seul import :

```dart
import 'package:pong_game/ui/pong_ui.dart';
```

## La règle d'or

**Un seul bouton rose plein par écran** (`PongPrimaryButton`), en bas, à portée de pouce.
Une sélection utilise le contour rose (`PongSelectableButton`, `PongChoiceCard`), jamais le
remplissage. `PongCompactButton` (rose sans halo) est réservé à l'action d'une ligne de liste.

Autres règles :
- **Couleur = sens.** Bleu = toi (`player`), vert = l'adversaire (`opponent`), or = record
  (`record`), rouge = erreur (`error`), podium (`gold`/`silver`/`bronze`) = classement seulement.
- **Le jeu d'abord.** En partie, seules la balle et les raquettes sont pleinement lumineuses ;
  le HUD utilise `PongText.gameScore` (blanc 22 %) et `PongText.hudLabel`.
- **Titres espacés** : on écrit « Classement », le composant affiche « CLASSEMENT » avec
  `letterSpacing`. Jamais d'espaces entre les lettres.
- **Chiffres qui changent** : styles tabulaires (`gameScore`, `keyFigure`, `listValue`, `figure`).
- **Textes** : tutoiement, phrases courtes qui disent quoi faire, en français.
- **Zones tactiles** ≥ 48 px : tous les composants les respectent.
- `onPressed: null` / `onTap: null` = désactivé, sur tous les composants tactiles.

## Jetons

| Fichier | Contenu |
|---|---|
| `pong_colors.dart` | `PongColors` : palette nommée par rôle (+ teintes précalculées, `podium(rang)`, `alpha()`). |
| `pong_text.dart` | `PongText` : logo, screenTitle, buttonLabel, buttonLabelPlain, overline, cardTitle, dialogTitle, headline, body, caption, gameScore, hudLabel, keyFigure, listValue, figure, pillLabel, statusLabel, segmentLabel, tileLabel. |
| `pong_tokens.dart` | `PongSpacing` (4·8·12·16·24·32, marge écran 20), `PongRadii` (12·14·16·18·24), `PongSizes` (48, 56, 64…), `PongShadows` (halos), `PongDurations`. |
| `pong_theme.dart` | `PongTheme.dark()` : `ThemeData` sombre branché dans `MaterialApp`. |

## Quel composant pour quel usage

| Besoin | Composant |
|---|---|
| Action principale de l'écran | `PongPrimaryButton(label, onPressed, icon?, expanded?)` |
| Action de second rang | `PongSecondaryButton(label, onPressed, icon?, compact?, expanded?)` |
| Sortie, lien discret | `PongTextButton(label, onPressed, icon?, color?)` |
| Icône seule (retour, pause, réglages) | `PongIconButton(icon, onPressed, tooltip, filled?, color?)` |
| Action d'une ligne de liste | `PongCompactButton(label, onPressed)` |
| Accès secondaires en tuiles | `PongTileButton(icon, label, onPressed)` dans `Row` + `Expanded` |
| Choisir parmi 2–4 valeurs | `PongSegmentedControl<T>(values, selected, onChanged, labelOf?)` |
| Un bouton de choix isolé | `PongSelectableButton(label, selected, onPressed)` |
| Grand choix (mode de jeu) | `PongChoiceCard(icon, title, subtitle?, selected, onTap, child?)` |
| Conteneur | `PongCard(child, padding?, borderColor?, onTap?, borderRadius?)` |
| Ligne de classement / de liste | `PongListRow(title, leading?, subtitle?, value?, trailing?, borderColor?, onTap?)` |
| Statistique | `PongStatCard(icon, label, value, color?)` |
| Petit chiffre + libellé | `PongFigureTile(value, label)` |
| Icône dans une pastille | `PongIconBadge(icon, color?, background?, size?, iconSize?, circular?)` |
| Saisie | `PongTextField(controller?, label?, hintText?, errorText?, shakeTrigger?, …)` |
| Logo | `PongLogo(fontSize?)` |
| Titre d'écran | `PongScreenTitle(text)` (placé par `PongHeaderBar`) |
| Sur-titre de section | `PongOverline(text, color?)` |
| Texte espacé centré | `PongSpacedText(text, style)` |
| Barre de titre | `PongHeaderBar(title?, center?, showBack?, onBack?, trailing?)` |
| Gabarit d'écran | `PongPageScaffold(body, title?, header?, showBack?, onBack?, trailing?, bottomAction?)` |
| Dialogue | `showPongDialog(context, builder)` + `PongDialogCard(icon?, iconColor?, title?, message?, content?, actions)` |
| Annonce (record, point) | `PongPill.signal(label, color, textColor?, icon?)` |
| État (prêt, en attente) | `PongPill.status(label, color?, textColor?, icon?)` |
| Jauges de jeu | `PongDotGauge(filled, count?, color?, label?)`, `PongBarGauge(filled, count?, color?)` |
| Élément tactile hors kit | `PongPressable` (base de tous les boutons) |

## Icônes

Material Symbols Rounded de la maquette = icônes Material intégrées, variante `_rounded`
(`Icons.leaderboard_rounded`, `Icons.bar_chart_rounded`, `Icons.help_rounded`,
`Icons.settings_rounded`, `Icons.pause_rounded`, `Icons.replay_rounded`,
`Icons.emoji_events_rounded`, `Icons.screen_rotation_rounded`, `Icons.wifi_rounded`,
`Icons.local_fire_department_rounded`, `Icons.star_rounded`, `Icons.bolt_rounded`…).
Aucune dépendance supplémentaire.

## Police

Archivo statique (400, 500, 600, 700, 800, 900) dans `assets/fonts/`, licence SIL OFL 1.1
(`assets/fonts/OFL.txt`), déclarée dans `pubspec.yaml`. Rien n'est téléchargé au lancement.
