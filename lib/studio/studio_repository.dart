// Présentation du studio pilotée par le site : cache local et
// rafraîchissement quotidien.
//
// Au démarrage, `main()` publie le cache (`loadCache`) puis lance
// `refreshIfDue` sans l'attendre : le chargement n'est jamais retardé, et
// l'app ne contacte le réseau qu'à ce moment-là (jamais pendant une partie
// ni un duel), au plus une fois par 24 h.
//
// Règles :
// - seul https://tilto.fun est contacté, pour l'API comme pour le logo ;
// - le logo n'est téléchargé que si son empreinte a changé, puis vérifié
//   (taille ≤ 1 Mo, type png/jpeg/webp, SHA-256, décodage) avant de
//   remplacer celui du cache ;
// - toute erreur (pas de réseau, délai, 5xx, JSON illisible, format
//   inconnu) laisse le cache tel quel, sans rien montrer au joueur ; le
//   journal `tilto.studio` en garde la trace ;
// - la présentation est demandée dans la langue de l'app
//   (`?lang=fr|en|es`). Le cache retient la langue de sa dernière
//   vérification : si la langue de l'app change, la vérification suivante
//   (au prochain lancement) a lieu même avant 24 h, et l'ETag d'une autre
//   langue n'est jamais renvoyé.
//
// Format de l'API : voir le contrat dans site/ (GET /api/app/studio).
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../brand.dart';
import 'studio_http.dart';
import 'studio_info.dart';

/// Dimensions d'une image décodée, ou `null` si elle ne se décode pas.
typedef StudioLogoDecoder = Future<({int width, int height})?> Function(
    Uint8List bytes);

/// Journal du studio.
typedef StudioLogger = void Function(String message);

void _defaultLog(String message) =>
    developer.log(message, name: 'tilto.studio');

/// Décode l'image avec le moteur de Flutter et renvoie ses dimensions.
Future<({int width, int height})?> decodeStudioLogo(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = (width: image.width, height: image.height);
      image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

class StudioRepository {
  StudioRepository(
    this._box, {
    StudioHttp? http,
    DateTime Function()? now,
    StudioLogoDecoder? decodeLogo,
    StudioLogger? log,
    ValueNotifier<StudioInfo>? notifier,
    Uri? apiUrl,
    this.language = defaultLanguage,
  })  : _http = http ?? const IoStudioHttp(),
        _now = now ?? DateTime.now,
        _decodeLogo = decodeLogo ?? decodeStudioLogo,
        _log = log ?? _defaultLog,
        notifier = notifier ?? Studio.current,
        apiUrl = apiUrl ?? Uri.parse(Brand.studioApiUrl);

  final Box<dynamic> _box;
  final StudioHttp _http;
  final DateTime Function() _now;
  final StudioLogoDecoder _decodeLogo;
  final StudioLogger _log;

  /// Ce que l'app affiche, mis à jour après chaque changement du cache.
  final ValueNotifier<StudioInfo> notifier;

  /// Adresse de l'API (les tests en essaient une autre pour vérifier
  /// qu'elle est refusée).
  final Uri apiUrl;

  /// Langue de l'app (`fr`, `en` ou `es`), envoyée au site.
  final String language;

  /// Langue des présentations enregistrées avant la version 1.1.0 (le site
  /// ne parlait que français).
  static const String defaultLanguage = 'fr';

  /// Adresse appelée : [apiUrl] avec la langue (`?lang=en`).
  Uri get requestUrl => apiUrl.replace(queryParameters: {
        ...apiUrl.queryParameters,
        'lang': language,
      });

  /// Nom de la boîte Hive, ouverte dans `main()`.
  static const String boxName = 'studio';

  /// Délai minimal entre deux vérifications réussies.
  static const Duration refreshInterval = Duration(hours: 24);

  /// Taille maximale de la réponse JSON et du logo.
  static const int maxJsonBytes = 64 * 1024;
  static const int maxLogoBytes = 1024 * 1024;

  /// Côté maximal du logo, en pixels.
  static const int maxLogoSide = 4096;

  // --- Clés Hive --------------------------------------------------------------
  static const String nameKey = 'name';
  static const String aboutKey = 'about';
  static const String websiteKey = 'website';
  static const String contactKey = 'contactUrl';
  static const String logoBytesKey = 'logoBytes';
  static const String logoShaKey = 'logoSha256';
  static const String logoWidthKey = 'logoWidth';
  static const String logoHeightKey = 'logoHeight';
  static const String etagKey = 'etag';
  static const String updatedAtKey = 'updatedAt';

  /// Dernière vérification réussie (millisecondes depuis l'époque).
  static const String lastCheckKey = 'lastCheck';

  /// Langue de la dernière vérification (et de l'ETag gardé). Absente :
  /// [defaultLanguage].
  static const String languageKey = 'language';

  bool _refreshing = false;

  /// Seule origine contactée : https://tilto.fun (port 443).
  static bool isAllowedUrl(Uri url) =>
      url.scheme == 'https' &&
      url.host == Brand.studioApiHost &&
      url.port == 443 &&
      url.userInfo.isEmpty;

  /// Présentation en cache ; valeurs intégrées pour ce qui manque.
  StudioInfo readCache() {
    const fallback = StudioInfo.fallback;
    final logo = _box.get(logoBytesKey);
    final width = _box.get(logoWidthKey);
    final height = _box.get(logoHeightKey);
    final hasLogo = logo is Uint8List && width is int && height is int;
    return StudioInfo(
      name: _string(nameKey) ?? fallback.name,
      about: _string(aboutKey) ?? fallback.about,
      website: _string(websiteKey) ?? fallback.website,
      contactUrl: _string(contactKey) ?? fallback.contactUrl,
      logo: hasLogo ? logo : null,
      logoWidth: hasLogo ? width : null,
      logoHeight: hasLogo ? height : null,
    );
  }

  /// Publie le cache dans [notifier] (au démarrage).
  void loadCache() => notifier.value = readCache();

  /// Langue de la dernière vérification.
  String get _checkedLanguage => _string(languageKey) ?? defaultLanguage;

  /// Vrai si aucune vérification n'a réussi depuis [refreshInterval]
  /// (ou si l'horloge du téléphone a reculé depuis), ou si la dernière a
  /// été faite dans une autre langue.
  bool get isDue {
    if (_checkedLanguage != language) return true;
    final last = _box.get(lastCheckKey);
    if (last is! int) return true;
    final elapsed = _now().millisecondsSinceEpoch - last;
    return elapsed < 0 || elapsed >= refreshInterval.inMilliseconds;
  }

  /// Interroge le site si la dernière vérification date de plus de 24 h.
  /// Ne lance jamais d'exception.
  Future<void> refreshIfDue() async {
    if (_refreshing || !isDue) return;
    _refreshing = true;
    try {
      await _refresh();
    } catch (error) {
      _log('vérification abandonnée : $error');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refresh() async {
    if (!isAllowedUrl(apiUrl)) {
      _log('adresse refusée : $apiUrl');
      return;
    }
    // L'ETag ne vaut que pour la langue dans laquelle il a été reçu
    final cachedEtag =
        _checkedLanguage == language ? _string(etagKey) : null;
    final response = await _http.get(requestUrl,
        ifNoneMatch: cachedEtag, maxBytes: maxJsonBytes);

    if (response.statusCode == 304 && cachedEtag != null) {
      _log('inchangé');
      await _markChecked();
      return;
    }
    if (response.statusCode != 200) {
      _log('réponse ${response.statusCode} ignorée');
      return;
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.body));
    } on FormatException {
      _log('JSON illisible');
      return;
    }
    final payload = StudioPayload.tryParse(json, isAllowedUrl: isAllowedUrl);
    if (payload == null) {
      // Format inconnu (autre `schema`, champs manquants, logo hors de
      // tilto.fun) : on garde le cache et on réessaiera demain.
      _log('réponse ignorée (format inconnu)');
      await _markChecked();
      return;
    }

    // Logo : celui du cache s'il n'a pas changé, sinon téléchargé et vérifié
    final logoRef = payload.logo;
    var logoUpdated = true;
    final Map<String, dynamic> logoValues;
    if (logoRef == null) {
      logoValues = {
        logoBytesKey: null,
        logoShaKey: null,
        logoWidthKey: null,
        logoHeightKey: null,
      };
    } else if (logoRef.sha256 == _string(logoShaKey) &&
        _box.get(logoBytesKey) is Uint8List) {
      logoValues = const {};
    } else {
      final logo = await _downloadLogo(logoRef);
      if (logo == null) {
        // Logo refusé : l'ancien reste, et l'ETag n'est pas gardé pour que
        // la prochaine vérification retente le téléchargement.
        logoUpdated = false;
        logoValues = const {};
      } else {
        logoValues = {
          logoBytesKey: logo.bytes,
          logoShaKey: logoRef.sha256,
          logoWidthKey: logo.width,
          logoHeightKey: logo.height,
        };
      }
    }

    await _box.putAll({
      nameKey: payload.name,
      aboutKey: payload.about,
      websiteKey: payload.website,
      contactKey: payload.contactUrl,
      updatedAtKey: payload.updatedAt,
      etagKey: logoUpdated ? response.etag : null,
      ...logoValues,
      lastCheckKey: _now().millisecondsSinceEpoch,
      languageKey: language,
    });
    _log('présentation mise à jour (${payload.updatedAt ?? 'sans date'})');
    loadCache();
  }

  Future<({Uint8List bytes, int width, int height})?> _downloadLogo(
      StudioLogoRef ref) async {
    if (!isAllowedUrl(ref.url)) {
      _log('logo refusé : adresse ${ref.url}');
      return null;
    }
    final StudioHttpResponse response;
    try {
      response = await _http.get(ref.url, maxBytes: maxLogoBytes);
    } on StudioHttpTooLarge {
      _log('logo refusé : plus de 1 Mo');
      return null;
    }
    if (response.statusCode != 200) {
      _log('logo refusé : réponse ${response.statusCode}');
      return null;
    }
    final type = response.contentType?.toLowerCase();
    if (!StudioPayload.logoTypes.contains(type)) {
      _log('logo refusé : type $type');
      return null;
    }
    final bytes = response.body;
    if (crypto.sha256.convert(bytes).toString() != ref.sha256) {
      _log('logo refusé : empreinte différente');
      return null;
    }
    final size = await _decodeLogo(bytes);
    if (size == null ||
        size.width < 1 ||
        size.height < 1 ||
        size.width > maxLogoSide ||
        size.height > maxLogoSide) {
      _log('logo refusé : image illisible');
      return null;
    }
    return (bytes: bytes, width: size.width, height: size.height);
  }

  /// Vérification faite sans nouvelle présentation : la prochaine attendra
  /// 24 h. Dans une nouvelle langue, l'ETag de l'ancienne est oublié.
  Future<void> _markChecked() => _box.putAll({
        lastCheckKey: _now().millisecondsSinceEpoch,
        if (_checkedLanguage != language) etagKey: null,
        languageKey: language,
      });

  String? _string(String key) {
    final value = _box.get(key);
    return value is String ? value : null;
  }
}
