// Client HTTP minimal du studio : un GET, avec délai et taille maximale.
//
// `IoStudioHttp` s'appuie sur `HttpClient` de dart:io (pas de dépendance) ;
// les tests passent leur propre `StudioHttp`. Aucune règle d'origine ici :
// `StudioRepository` vérifie l'adresse avant d'appeler `get`.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../brand.dart';

/// Réponse d'un GET.
class StudioHttpResponse {
  const StudioHttpResponse({
    required this.statusCode,
    required this.body,
    this.etag,
    this.contentType,
  });

  final int statusCode;
  final Uint8List body;

  /// En-tête `ETag`, tel quel.
  final String? etag;

  /// Type de contenu sans paramètres (`image/png`, `application/json`).
  final String? contentType;
}

/// Réponse plus longue que la taille permise.
class StudioHttpTooLarge implements Exception {
  const StudioHttpTooLarge();

  @override
  String toString() => 'réponse trop longue';
}

/// Un GET : statut, corps (au plus [maxBytes] octets), `ETag`, type.
abstract interface class StudioHttp {
  Future<StudioHttpResponse> get(
    Uri url, {
    String? ifNoneMatch,
    required int maxBytes,
  });
}

/// GET par `HttpClient`, sans suivre les redirections (elles pourraient
/// mener hors de tilto.fun), en [timeout] au plus du début à la fin.
class IoStudioHttp implements StudioHttp {
  const IoStudioHttp({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  @override
  Future<StudioHttpResponse> get(
    Uri url, {
    String? ifNoneMatch,
    required int maxBytes,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = '${Brand.gameName}/${Brand.appVersion}';
    try {
      return await _get(client, url, ifNoneMatch, maxBytes).timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<StudioHttpResponse> _get(
      HttpClient client, Uri url, String? ifNoneMatch, int maxBytes) async {
    final request = await client.getUrl(url);
    request.followRedirects = false;
    if (ifNoneMatch != null) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, ifNoneMatch);
    }
    final response = await request.close();
    if (response.contentLength > maxBytes) throw const StudioHttpTooLarge();
    final body = BytesBuilder(copy: false);
    await for (final chunk in response) {
      body.add(chunk);
      if (body.length > maxBytes) throw const StudioHttpTooLarge();
    }
    return StudioHttpResponse(
      statusCode: response.statusCode,
      body: body.takeBytes(),
      etag: response.headers.value(HttpHeaders.etagHeader),
      contentType: response.headers.contentType?.mimeType,
    );
  }
}
