// Présentation du studio pilotée par le site : lecture de la réponse,
// cache Hive, ETag, logo (origine, taille, type, empreinte, décodage),
// rythme de 24 h et erreurs silencieuses. Client HTTP factice, horloge
// réglable ; boîte Hive en mémoire.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pong_game/brand.dart';
import 'package:pong_game/studio/studio_http.dart';
import 'package:pong_game/studio/studio_info.dart';
import 'package:pong_game/studio/studio_repository.dart';

final Uri _api = Uri.parse(Brand.studioApiUrl);
final Uri _logoUrl = Uri.parse('https://tilto.fun/media/logo-v2.png');

/// Faux logo : son contenu importe peu, le décodeur factice l'accepte.
final Uint8List _logoBytes = Uint8List.fromList(List.generate(300, (i) => i % 251));
final String _logoSha = crypto.sha256.convert(_logoBytes).toString();

Map<String, dynamic> _payload({
  Object? schema = 1,
  String name = 'Orbis',
  String about = 'Premier paragraphe.\n\nSecond paragraphe.',
  Object? logo = const _DefaultLogo(),
}) =>
    {
      'schema': schema,
      'studio': {
        'name': name,
        'about': about,
        'website': 'https://tilto.fun',
        'contact_url': 'https://tilto.fun/contact',
      },
      'logo': logo is _DefaultLogo
          ? {
              'url': _logoUrl.toString(),
              'sha256': _logoSha,
              'width': 221,
              'height': 48,
              'content_type': 'image/png',
            }
          : logo,
      'updated_at': '2026-10-12T10:00:00+00:00',
    };

class _DefaultLogo {
  const _DefaultLogo();
}

StudioHttpResponse _json(Object body, {String? etag = '"v1"'}) =>
    StudioHttpResponse(
      statusCode: 200,
      body: Uint8List.fromList(utf8.encode(jsonEncode(body))),
      etag: etag,
      contentType: 'application/json',
    );

StudioHttpResponse _png(Uint8List bytes, {String type = 'image/png'}) =>
    StudioHttpResponse(statusCode: 200, body: bytes, contentType: type);

/// Client factice : une réponse (ou une erreur) par adresse, et la liste
/// des appels reçus.
class _FakeHttp implements StudioHttp {
  final Map<Uri, Object Function()> routes = {};
  final List<({Uri url, String? ifNoneMatch, int maxBytes})> calls = [];

  void on(Uri url, Object Function() reply) => routes[url] = reply;

  int callsTo(Uri url) => calls.where((call) => call.url == url).length;

  @override
  Future<StudioHttpResponse> get(Uri url,
      {String? ifNoneMatch, required int maxBytes}) async {
    calls.add((url: url, ifNoneMatch: ifNoneMatch, maxBytes: maxBytes));
    final reply = routes[url];
    if (reply == null) throw const SocketException('hôte inconnu');
    final value = reply();
    if (value is StudioHttpResponse) {
      if (value.body.length > maxBytes) throw const StudioHttpTooLarge();
      return value;
    }
    throw value;
  }
}

void main() {
  late Box<dynamic> box;
  late _FakeHttp http;
  late DateTime now;
  late ValueNotifier<StudioInfo> notifier;
  late List<String> logs;
  var boxCount = 0;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('tilto_studio_test');
    Hive.init(dir.path);
  });

  setUp(() async {
    box = await Hive.openBox('studio_${boxCount++}', bytes: Uint8List(0));
    http = _FakeHttp();
    now = DateTime.utc(2026, 10, 12, 9);
    notifier = ValueNotifier(StudioInfo.fallback);
    logs = [];
  });

  StudioRepository repo({Uri? apiUrl, StudioLogoDecoder? decode}) =>
      StudioRepository(
        box,
        http: http,
        now: () => now,
        decodeLogo: decode ?? (_) async => (width: 221, height: 48),
        log: logs.add,
        notifier: notifier,
        apiUrl: apiUrl,
      );

  void serveValid({Map<String, dynamic>? body, String? etag = '"v1"'}) {
    http.on(_api, () => _json(body ?? _payload(), etag: etag));
    http.on(_logoUrl, () => _png(_logoBytes));
  }

  group('premier lancement', () {
    test('sans cache : les valeurs intégrées (Brand)', () {
      final info = repo().readCache();
      expect(info.name, Brand.studioName);
      expect(info.about, isEmpty);
      expect(info.paragraphs, isEmpty);
      expect(info.website, Brand.studioWebsite);
      expect(info.contactUrl, Brand.studioContactUrl);
      expect(info.logo, isNull);
      expect(info.usesBuiltInLogo, isTrue);
      expect(info.logoAspectRatio, Brand.logoLightAspectRatio);
      expect(repo().isDue, isTrue);
    });
  });

  group('réponse valide', () {
    test('mise en cache, publiée, logo téléchargé et vérifié', () async {
      serveValid();
      await repo().refreshIfDue();

      expect(http.calls.first.url, _api);
      expect(http.calls.first.ifNoneMatch, isNull);
      expect(http.calls.first.maxBytes, StudioRepository.maxJsonBytes);
      expect(http.callsTo(_logoUrl), 1);
      expect(http.calls.last.maxBytes, StudioRepository.maxLogoBytes);

      final info = notifier.value;
      expect(info.name, 'Orbis');
      expect(info.paragraphs, ['Premier paragraphe.', 'Second paragraphe.']);
      expect(info.logo, _logoBytes);
      expect(info.logoAspectRatio, 221 / 48);
      expect(info.usesBuiltInLogo, isFalse);

      // Relu depuis la boîte : identique
      final cached = repo().readCache();
      expect(cached.name, 'Orbis');
      expect(cached.logo, _logoBytes);
      expect(box.get(StudioRepository.etagKey), '"v1"');
      expect(box.get(StudioRepository.logoShaKey), _logoSha);
      expect(box.get(StudioRepository.updatedAtKey),
          '2026-10-12T10:00:00+00:00');
      expect(box.get(StudioRepository.lastCheckKey),
          now.millisecondsSinceEpoch);
    });

    test('304 : le cache reste, If-None-Match envoyé', () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.add(const Duration(hours: 25));
      http.calls.clear();
      http.on(_api, () => StudioHttpResponse(
          statusCode: 304, body: Uint8List(0), etag: '"v1"'));

      await repo().refreshIfDue();
      expect(http.calls.single.ifNoneMatch, '"v1"');
      expect(repo().readCache().name, 'Orbis');
      expect(repo().readCache().logo, _logoBytes);
      expect(box.get(StudioRepository.lastCheckKey),
          now.millisecondsSinceEpoch);
    });

    test('même empreinte : le logo n\'est pas retéléchargé', () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.add(const Duration(days: 2));
      serveValid(body: _payload(name: 'Orbis Studio'), etag: '"v2"');
      http.calls.clear();

      await repo().refreshIfDue();
      expect(http.callsTo(_logoUrl), 0);
      expect(notifier.value.name, 'Orbis Studio');
      expect(notifier.value.logo, _logoBytes);
    });

    test('logo null : retour au logo intégré', () async {
      serveValid(body: _payload(name: Brand.studioName));
      await repo().refreshIfDue();
      expect(notifier.value.logo, isNotNull);

      now = now.add(const Duration(days: 1));
      http.on(_api,
          () => _json(_payload(name: Brand.studioName, logo: null), etag: '"v2"'));
      await repo().refreshIfDue();
      expect(notifier.value.logo, isNull);
      expect(notifier.value.usesBuiltInLogo, isTrue);
      expect(box.get(StudioRepository.logoShaKey), isNull);
    });

    test('autre nom sans logo : le nom s\'écrit en texte', () async {
      http.on(_api, () => _json(_payload(name: 'Orbis', logo: null)));
      await repo().refreshIfDue();
      expect(notifier.value.usesBuiltInLogo, isFalse);
      expect(notifier.value.showsNameAsText, isTrue);
    });
  });

  group('logo refusé', () {
    test('empreinte fausse : textes à jour, ancien logo gardé, ETag oublié',
        () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.add(const Duration(days: 1));

      // Nouveau logo annoncé, mais les octets reçus ne correspondent pas
      final newLogo = Uri.parse('https://tilto.fun/media/logo-v3.png');
      http.on(_api, () => _json(_payload(name: 'Orbis 2', logo: {
            'url': newLogo.toString(),
            'sha256': 'ab' * 32,
            'content_type': 'image/png',
          }), etag: '"v3"'));
      http.on(newLogo, () => _png(Uint8List.fromList([1, 2, 3])));
      await repo().refreshIfDue();

      expect(notifier.value.name, 'Orbis 2');
      expect(notifier.value.logo, _logoBytes);
      expect(box.get(StudioRepository.logoShaKey), _logoSha);
      // Sans ETag, la prochaine vérification retentera le logo
      expect(box.get(StudioRepository.etagKey), isNull);
      expect(logs, contains('logo refusé : empreinte différente'));
    });

    test('type non accepté', () async {
      http.on(_api, () => _json(_payload()));
      http.on(_logoUrl, () => _png(_logoBytes, type: 'image/svg+xml'));
      await repo().refreshIfDue();
      expect(notifier.value.logo, isNull);
    });

    test('plus de 1 Mo', () async {
      final big = Uint8List(StudioRepository.maxLogoBytes + 1);
      final body = _payload(logo: {
        'url': _logoUrl.toString(),
        'sha256': crypto.sha256.convert(big).toString(),
        'content_type': 'image/png',
      });
      http.on(_api, () => _json(body));
      http.on(_logoUrl, () => _png(big));
      await repo().refreshIfDue();
      expect(notifier.value.logo, isNull);
      expect(logs, contains('logo refusé : plus de 1 Mo'));
    });

    test('image qui ne se décode pas', () async {
      serveValid();
      await repo(decode: (_) async => null).refreshIfDue();
      expect(notifier.value.logo, isNull);
      expect(logs, contains('logo refusé : image illisible'));
    });

    test('vrai décodeur : un PNG passe, des octets quelconques non',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final png = File('assets/brand/nexora_mark.png').readAsBytesSync();
      final size = await decodeStudioLogo(png);
      expect(size, isNotNull);
      expect(size!.width, greaterThan(0));
      expect(await decodeStudioLogo(Uint8List.fromList([1, 2, 3, 4])),
          isNull);
    });
  });

  group('origine', () {
    test('logo hors de tilto.fun : réponse refusée, rien de téléchargé',
        () async {
      final evil = Uri.parse('https://evil.example/logo.png');
      http.on(_api, () => _json(_payload(logo: {
            'url': evil.toString(),
            'sha256': _logoSha,
            'content_type': 'image/png',
          })));
      http.on(evil, () => _png(_logoBytes));
      await repo().refreshIfDue();
      expect(http.callsTo(evil), 0);
      expect(notifier.value.name, Brand.studioName);
      expect(box.get(StudioRepository.nameKey), isNull);
    });

    test('logo en http ou sur un autre port : refusé', () {
      for (final url in [
        'http://tilto.fun/media/a.png',
        'https://tilto.fun:8443/media/a.png',
        'https://user@tilto.fun/media/a.png',
        'https://tilto.fun.evil.example/a.png',
      ]) {
        expect(StudioRepository.isAllowedUrl(Uri.parse(url)), isFalse,
            reason: url);
      }
      expect(StudioRepository.isAllowedUrl(_logoUrl), isTrue);
    });

    test('API hors de tilto.fun : aucun appel', () async {
      final other = Uri.parse('https://evil.example/api/app/studio');
      http.on(other, () => _json(_payload()));
      await repo(apiUrl: other).refreshIfDue();
      expect(http.calls, isEmpty);
      expect(notifier.value.name, Brand.studioName);
    });
  });

  group('réponses ignorées', () {
    test('schema différent de 1 : ignoré', () async {
      http.on(_api, () => _json(_payload(schema: 2)));
      await repo().refreshIfDue();
      expect(notifier.value.name, Brand.studioName);
      expect(box.get(StudioRepository.nameKey), isNull);
      expect(http.callsTo(_logoUrl), 0);
    });

    test('JSON illisible : cache gardé', () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.add(const Duration(days: 1));
      http.on(_api, () => StudioHttpResponse(
          statusCode: 200, body: Uint8List.fromList(utf8.encode('{oups'))));
      await repo().refreshIfDue();
      expect(repo().readCache().name, 'Orbis');
    });

    test('erreur 500 et réseau absent : silencieux, cache gardé, réessai '
        'au prochain lancement', () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.add(const Duration(days: 1));

      http.on(_api, () => StudioHttpResponse(statusCode: 500, body: Uint8List(0)));
      await repo().refreshIfDue();
      expect(repo().readCache().name, 'Orbis');
      expect(repo().isDue, isTrue);

      http.on(_api, () => const SocketException('pas de réseau'));
      await expectLater(repo().refreshIfDue(), completes);
      expect(repo().readCache().name, 'Orbis');
      expect(repo().readCache().logo, _logoBytes);
      expect(repo().isDue, isTrue);
    });
  });

  group('rythme', () {
    test('pas de nouvel appel avant 24 h', () async {
      serveValid();
      await repo().refreshIfDue();
      expect(http.callsTo(_api), 1);

      now = now.add(const Duration(hours: 23, minutes: 59));
      await repo().refreshIfDue();
      expect(http.callsTo(_api), 1);

      now = now.add(const Duration(minutes: 1));
      await repo().refreshIfDue();
      expect(http.callsTo(_api), 2);
    });

    test('horloge qui recule : nouvelle vérification', () async {
      serveValid();
      await repo().refreshIfDue();
      now = now.subtract(const Duration(days: 3));
      expect(repo().isDue, isTrue);
    });

    test('loadCache publie le cache sans appel réseau', () async {
      serveValid();
      await repo().refreshIfDue();
      notifier.value = StudioInfo.fallback;
      http.calls.clear();
      repo().loadCache();
      expect(notifier.value.name, 'Orbis');
      expect(http.calls, isEmpty);
    });
  });

  group('nettoyage des textes', () {
    test('nom : une ligne, 60 caractères au plus', () {
      expect(StudioPayload.cleanName('  Orbis\n\tStudio\u0007 '), 'Orbis Studio');
      expect(StudioPayload.cleanName('x' * 80)!.length, 60);
      expect(StudioPayload.cleanName('   '), isNull);
      expect(StudioPayload.cleanName(42), isNull);
    });

    test('présentation : paragraphes, 800 caractères au plus', () {
      expect(StudioPayload.cleanAbout('A  b\r\n\r\n\r\n\r\nC\u0000d  '),
          'A b\n\nC d');
      final long = StudioPayload.cleanAbout('mot ' * 400);
      expect(long.length, lessThanOrEqualTo(StudioInfo.maxAboutLength));
      expect(long, endsWith('…'));
      expect(StudioPayload.cleanAbout(null), '');
    });

    test('liens : https seulement, sinon ceux de l\'app', () {
      expect(StudioPayload.cleanLink('https://tilto.fun/contact'),
          'https://tilto.fun/contact');
      expect(StudioPayload.cleanLink('javascript:alert(1)'), isNull);
      expect(StudioPayload.cleanLink('http://tilto.fun'), isNull);
      final payload = StudioPayload.tryParse({
        'schema': 1,
        'studio': {'name': 'Orbis', 'website': 'ftp://x', 'contact_url': 3},
        'logo': null,
      }, isAllowedUrl: StudioRepository.isAllowedUrl)!;
      expect(payload.website, Brand.studioWebsite);
      expect(payload.contactUrl, Brand.studioContactUrl);
      expect(payload.about, '');
    });
  });
}
