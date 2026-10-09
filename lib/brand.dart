// Marque du jeu et du studio : le seul endroit où leurs noms et leurs logos
// sont écrits. Tout le code lit ces valeurs.
//
// Changer de studio : modifier [Brand.studioName] et remplacer les trois
// images de `assets/brand/` (mêmes noms de fichiers, ou nouveaux chemins
// ci-dessous), puis ajuster [Brand.logoLightAspectRatio].
//
// Hors de ce fichier, seuls l'identifiant du paquet (`pong_game`), le nom
// sous l'icône (AndroidManifest.xml, Info.plist) et la documentation
// citent le jeu ou le studio.

/// Noms et logos du jeu et du studio.
abstract final class Brand {
  /// Nom du jeu, tel qu'il s'écrit dans une phrase (« Tilto »).
  static const String gameName = 'Tilto';

  /// Nom du studio (« Nexora »).
  static const String studioName = 'Nexora';

  /// Signature discrète, en bas des Réglages et de l'Aide.
  static const String signature = 'Un jeu de $studioName';

  /// Début de la signature, suivi du logo (qui contient le nom du studio).
  static const String signaturePrefix = 'Un jeu de';

  /// Logo complet (symbole + nom), texte blanc : pour les fonds sombres.
  static const String logoLight = 'assets/brand/nexora_logo_light.png';

  /// Logo complet d'origine, texte bleu nuit : pour les fonds clairs.
  static const String logoDark = 'assets/brand/nexora_logo_dark.png';

  /// Symbole seul.
  static const String mark = 'assets/brand/nexora_mark.png';

  /// Largeur / hauteur de [logoLight] (1561 × 339 px) : réserve la place
  /// du logo avant que l'image soit décodée.
  static const double logoLightAspectRatio = 1561 / 339;
}
