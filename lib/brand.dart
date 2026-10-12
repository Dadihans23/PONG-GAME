// Marque du jeu et du studio : le seul endroit où leurs noms et leurs logos
// sont écrits. Tout le code lit ces valeurs.
//
// Le nom du studio, son logo et sa présentation sont pilotés par le site
// (administration de tilto.fun, lus par lib/studio/) : les valeurs ci-dessous
// ne servent qu'au premier lancement et quand le site ne répond pas.
//
// Changer de studio dans l'app elle-même : modifier [Brand.studioName] et
// remplacer les trois images de `assets/brand/` (mêmes noms de fichiers, ou
// nouveaux chemins ci-dessous), puis ajuster [Brand.logoLightAspectRatio].
//
// Hors de ce fichier, seuls l'identifiant du paquet (`pong_game`), le nom
// sous l'icône (AndroidManifest.xml, Info.plist) et la documentation
// citent le jeu ou le studio.

/// Noms et logos du jeu et du studio.
abstract final class Brand {
  /// Nom du jeu, tel qu'il s'écrit dans une phrase (« Tilto »).
  static const String gameName = 'Tilto';

  /// Version affichée (Réglages, page « Le studio ») : la même que
  /// `version:` dans pubspec.yaml, sans le numéro de build (vérifié par
  /// test/settings_test.dart). À changer avec le pubspec.
  static const String appVersion = '1.1.0';

  /// Nom du studio (« Nexora »).
  static const String studioName = 'Nexora';

  /// Site du studio, par défaut.
  static const String studioWebsite = 'https://tilto.fun';

  /// Page de contact du studio, par défaut.
  static const String studioContactUrl = 'https://tilto.fun/contact';

  /// Seul hôte que l'app contacte, pour l'API et le logo du studio.
  static const String studioApiHost = 'tilto.fun';

  /// Présentation du studio (nom, logo, texte, liens), modifiable dans
  /// l'administration du site. Voir lib/studio/studio_repository.dart.
  static const String studioApiUrl = 'https://$studioApiHost/api/app/studio';

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
