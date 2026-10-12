// Présentation du studio telle que l'app l'affiche (signature des Réglages
// et de l'Aide, page « Le studio »), et lecture de la réponse du site.
//
// Dart pur : aucun widget, aucun accès réseau ni disque. Les valeurs par
// défaut sont celles de lib/brand.dart ; le site (administration de
// tilto.fun) les remplace, voir studio_repository.dart.
import 'package:flutter/foundation.dart';

import '../brand.dart';

/// Nom, présentation, liens et logo du studio.
@immutable
class StudioInfo {
  const StudioInfo({
    required this.name,
    required this.about,
    required this.website,
    required this.contactUrl,
    this.logo,
    this.logoWidth,
    this.logoHeight,
  });

  /// Valeurs intégrées à l'app : premier lancement, site injoignable.
  static const StudioInfo fallback = StudioInfo(
    name: Brand.studioName,
    about: '',
    website: Brand.studioWebsite,
    contactUrl: Brand.studioContactUrl,
  );

  /// Nom du studio, nettoyé (≤ [maxNameLength] caractères, jamais vide).
  final String name;

  /// Présentation : paragraphes séparés par une ligne vide, peut être vide.
  final String about;

  /// Site du studio (https).
  final String website;

  /// Page de contact (https).
  final String contactUrl;

  /// Logo téléchargé du site, déjà vérifié (empreinte, décodage) ; `null` =
  /// logo intégré, ou nom en texte si le studio a changé de nom.
  final Uint8List? logo;

  /// Dimensions du logo téléchargé, en pixels (lues au décodage).
  final int? logoWidth;
  final int? logoHeight;

  static const int maxNameLength = 60;
  static const int maxAboutLength = 800;

  /// Le logo intégré (`Brand.logoLight`) ne vaut que pour le studio
  /// d'origine : si le site donne un autre nom sans logo, on écrit le nom.
  bool get usesBuiltInLogo => logo == null && name == Brand.studioName;

  /// Ni logo téléchargé ni logo intégré : le nom s'écrit en texte.
  bool get showsNameAsText => logo == null && !usesBuiltInLogo;

  /// Largeur / hauteur du logo affiché.
  double get logoAspectRatio {
    final width = logoWidth, height = logoHeight;
    if (logo != null && width != null && height != null && height > 0) {
      return width / height;
    }
    return Brand.logoLightAspectRatio;
  }

  /// Paragraphes de la présentation, sans les vides.
  List<String> get paragraphs => [
        for (final part in about.split(RegExp(r'\n[ \t]*\n')))
          if (part.trim().isNotEmpty) part.trim(),
      ];

  StudioInfo copyWith({
    String? name,
    String? about,
    String? website,
    String? contactUrl,
  }) =>
      StudioInfo(
        name: name ?? this.name,
        about: about ?? this.about,
        website: website ?? this.website,
        contactUrl: contactUrl ?? this.contactUrl,
        logo: logo,
        logoWidth: logoWidth,
        logoHeight: logoHeight,
      );
}

/// Ce que l'app affiche du studio, partagé par tous les écrans. Mis à jour
/// par `StudioRepository` au démarrage (cache) puis si le site a changé ;
/// la signature et la page « Le studio » l'écoutent.
abstract final class Studio {
  static final ValueNotifier<StudioInfo> current =
      ValueNotifier<StudioInfo>(StudioInfo.fallback);
}

/// Logo annoncé par le site (pas encore téléchargé).
@immutable
class StudioLogoRef {
  const StudioLogoRef({
    required this.url,
    required this.sha256,
    required this.contentType,
  });

  final Uri url;

  /// Empreinte SHA-256 attendue, en hexadécimal minuscule (64 caractères).
  final String sha256;
  final String contentType;
}

/// Réponse du site, lue et nettoyée.
@immutable
class StudioPayload {
  const StudioPayload({
    required this.name,
    required this.about,
    required this.website,
    required this.contactUrl,
    required this.logo,
    required this.updatedAt,
  });

  final String name;
  final String about;
  final String website;
  final String contactUrl;

  /// `null` : le site n'a pas de logo, l'app reprend le sien.
  final StudioLogoRef? logo;
  final String? updatedAt;

  /// Seule version du format que cette app comprend.
  static const int schema = 1;

  /// Types d'image acceptés pour le logo.
  static const Set<String> logoTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
  };

  /// Lit le JSON décodé de `GET /api/app/studio`. `null` si la réponse ne
  /// suit pas le format (autre `schema`, champs manquants) : l'app la
  /// laisse de côté. Un logo mal décrit vaut « pas de logo du site » ;
  /// [isAllowedUrl] dit si son adresse peut être contactée.
  static StudioPayload? tryParse(
    Object? json, {
    required bool Function(Uri url) isAllowedUrl,
  }) {
    if (json is! Map<String, dynamic>) return null;
    if (json['schema'] != schema) return null;
    final studio = json['studio'];
    if (studio is! Map<String, dynamic>) return null;

    final name = cleanName(studio['name']);
    final about = cleanAbout(studio['about']);
    final website =
        cleanLink(studio['website']) ?? StudioInfo.fallback.website;
    final contact =
        cleanLink(studio['contact_url']) ?? StudioInfo.fallback.contactUrl;
    final updatedAt = json['updated_at'];

    final logoJson = json['logo'];
    StudioLogoRef? logo;
    if (logoJson != null) {
      if (logoJson is! Map<String, dynamic>) return null;
      logo = _parseLogo(logoJson, isAllowedUrl);
      // Logo annoncé mais inutilisable (autre origine, empreinte ou type
      // invalides) : on refuse toute la réponse plutôt que d'effacer le
      // logo en cache sur la foi d'une réponse douteuse.
      if (logo == null) return null;
    }

    return StudioPayload(
      name: name ?? StudioInfo.fallback.name,
      about: about,
      website: website,
      contactUrl: contact,
      logo: logo,
      updatedAt: updatedAt is String && updatedAt.length <= 64
          ? updatedAt
          : null,
    );
  }

  static StudioLogoRef? _parseLogo(
      Map<String, dynamic> json, bool Function(Uri url) isAllowedUrl) {
    final rawUrl = json['url'];
    final sha = json['sha256'];
    final type = json['content_type'];
    if (rawUrl is! String || sha is! String || type is! String) return null;
    final url = Uri.tryParse(rawUrl);
    if (url == null || !isAllowedUrl(url)) return null;
    final hash = sha.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return null;
    final contentType = type.toLowerCase().trim();
    if (!logoTypes.contains(contentType)) return null;
    return StudioLogoRef(url: url, sha256: hash, contentType: contentType);
  }

  // Caractères de contrôle, sauf le saut de ligne
  static final RegExp _control = RegExp('[\x00-\x09\x0B-\x1F\x7F'
      '\u200B-\u200F\u202A-\u202E\u2066-\u2069]');

  /// Nom : une ligne, espaces réduits, ≤ 60 caractères. `null` si vide.
  static String? cleanName(Object? value) {
    if (value is! String) return null;
    final name = value
        .replaceAll(_control, ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) return null;
    return _cut(name, StudioInfo.maxNameLength);
  }

  /// Présentation : paragraphes séparés par une seule ligne vide, lignes
  /// sans espaces superflus, ≤ 800 caractères (coupée au dernier mot).
  static String cleanAbout(Object? value) {
    if (value is! String) return '';
    final lines = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_control, ' ')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t ]+'), ' ').trim());
    final text = lines
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.length <= StudioInfo.maxAboutLength) return text;
    final cut = text.substring(0, StudioInfo.maxAboutLength - 1);
    final lastSpace = cut.lastIndexOf(RegExp(r'\s'));
    final base = lastSpace > StudioInfo.maxAboutLength ~/ 2
        ? cut.substring(0, lastSpace)
        : cut;
    return '${base.trimRight()}…';
  }

  /// Lien ouvert dans le navigateur : https, avec un hôte, ≤ 300
  /// caractères. `null` sinon (l'app reprend son lien par défaut).
  static String? cleanLink(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty || text.length > 300) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  static String _cut(String text, int max) => text.length <= max
      ? text
      : String.fromCharCodes(text.runes.take(max)).trimRight();
}
