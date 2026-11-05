import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'sports_api_service.dart';

const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

class SportsChannel {
  const SportsChannel({
    required this.id,
    required this.identifier,
    required this.name,
    required this.url,
    this.logoUrl = '',
    this.groupTitle = '',
    this.isSports = true,
    this.visible = true,
    this.language = 'unknown',
  });

  final String id;
  final String identifier;
  final String name;
  final String url;
  final String logoUrl;
  final String groupTitle;
  final bool isSports;
  final bool visible;
  final String language;

  factory SportsChannel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['identifier'] ?? '').toString().trim();
    final identifier =
        (json['identifier'] ?? json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    final url = (json['url'] ?? '').toString().trim();
    final logoUrl = (json['logoUrl'] ?? '').toString().trim();
    final groupTitle = (json['groupTitle'] ?? '').toString().trim();
    final rawLanguage = (json['language'] ?? 'unknown').toString().trim().toLowerCase();
    final language = const <String>{'es', 'en'}.contains(rawLanguage)
        ? rawLanguage
        : 'unknown';
    if (id.isEmpty || identifier.isEmpty || name.isEmpty || url.isEmpty) {
      throw const FormatException('El canal recibido está incompleto.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !(uri.path.toLowerCase().endsWith('.m3u8') ||
            uri.path.toLowerCase().endsWith('.mp4') ||
            uri.path.toLowerCase().endsWith('.ts'))) {
      throw const FormatException('El canal no contiene una señal HTTPS directa válida.');
    }
    return SportsChannel(
      id: id,
      identifier: identifier,
      name: name,
      url: url,
      logoUrl: logoUrl,
      groupTitle: groupTitle,
      isSports: json['isSports'] == true,
      visible: json['visible'] != false,
      language: language,
    );
  }
}

class ChannelPlaylistSource {
  const ChannelPlaylistSource({
    required this.id,
    required this.url,
    required this.label,
    required this.status,
    this.lastError = '',
    this.importedCount = 0,
    this.lastImportedAt = '',
  });

  final String id;
  final String url;
  final String label;
  final String status;
  final String lastError;
  final int importedCount;
  final String lastImportedAt;

  factory ChannelPlaylistSource.fromJson(Map<String, dynamic> json) {
    return ChannelPlaylistSource(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      label: (json['label'] ?? 'Lista IPTV').toString(),
      status: (json['status'] ?? 'queued').toString(),
      lastError: (json['last_error'] ?? '').toString(),
      importedCount: int.tryParse(
            (json['imported_count'] ?? 0).toString(),
          ) ??
          0,
      lastImportedAt: (json['last_imported_at'] ?? '').toString(),
    );
  }
}

class ChannelCatalogPage {
  const ChannelCatalogPage({
    required this.channels,
    required this.total,
    required this.offset,
    required this.hasMore,
  });

  final List<SportsChannel> channels;
  final int total;
  final int offset;
  final bool hasMore;
}

class ChannelCatalogException implements Exception {
  const ChannelCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ChannelCatalogService {
  ChannelCatalogService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static final GoogleSignIn _google = GoogleSignIn.instance;
  static Future<void>? _initialization;
  String? _idToken;
  String? signedInEmail;

  String get _baseUrl {
    final normalized =
        SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (normalized == null) {
      throw const ChannelCatalogException(
        'La dirección del servidor Cloudflare no es válida.',
      );
    }
    return normalized;
  }

  Future<void> _initializeGoogle() {
    return _initialization ??= _google.initialize(
      serverClientId:
          _googleServerClientId.isEmpty ? null : _googleServerClientId,
    );
  }

  Future<String> signIn() async {
    // Reutiliza la sesión ya autenticada dentro del proceso. Evita volver a
    // abrir Credential Manager para la misma cuenta en cada sincronización,
    // una ruta que puede terminar en [16] Account reauth failed en Android.
    final currentToken = _idToken;
    final currentEmail = signedInEmail;
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        currentEmail != null &&
        currentEmail.isNotEmpty) {
      return currentEmail;
    }

    if (_googleServerClientId.isEmpty) {
      throw const ChannelCatalogException(
        'Falta configurar GOOGLE_OAUTH_CLIENT_ID en la compilación de la APK.',
      );
    }
    await _initializeGoogle();
    if (!_google.supportsAuthenticate()) {
      throw const ChannelCatalogException(
        'El inicio de sesión Google no está disponible en este dispositivo.',
      );
    }
    try {
      // El token se mantiene solo en memoria. Cuando Android destruye el
      // proceso, Credential Manager puede conservar la relación de la cuenta
      // anterior. Si llamamos authenticate() directamente en el siguiente
      // arranque, algunos dispositivos responden [16] Account reauth failed.
      // Primero cerramos la sesión nativa anterior, incluso si la app se
      // cerró sin que el usuario pulsara "Cerrar sesión".
      await _google.signOut();
      final account = await _google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ChannelCatalogException(
          'Google no entregó un ID token. Revisa el cliente OAuth Web y Android.',
        );
      }
      _idToken = token;
      signedInEmail = account.email;
      return account.email;
    } on GoogleSignInException {
      // Credential Manager puede conservar una cuenta previa aunque el
      // intento falle antes de devolver un usuario. Limpia siempre esa sesión
      // para que el siguiente intento no repita el error de reautenticación [16].
      _idToken = null;
      signedInEmail = null;
      try {
        await _google.signOut();
      } catch (_) {
        // Conserva el error original del inicio de sesión.
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _initializeGoogle();
      // Google también debe cerrar su sesión de Credential Manager; cerrar
      // únicamente la sesión del backend deja una cuenta anterior en caché.
      await _google.signOut();
    } finally {
      _idToken = null;
      signedInEmail = null;
    }
  }

  Map<String, dynamic> _decode(http.Response result) {
    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(result.body);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // El código HTTP sigue siendo útil aunque el cuerpo no sea JSON.
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map
          ? (error['message'] ?? error['code'] ?? 'Error del servidor')
              .toString()
          : error?.toString() ?? 'El servidor respondió HTTP ' +
              result.statusCode.toString();
      if (result.statusCode == 401) {
        _idToken = null;
        signedInEmail = null;
      }
      throw ChannelCatalogException(message);
    }
    return payload;
  }

  Map<String, String> _authHeaders() {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      throw const ChannelCatalogException(
        'Inicia sesión con Google para continuar.',
      );
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ' + token,
    };
  }

  /// Descarga solo una página del catálogo. La interfaz solicita las
  /// siguientes al desplazarse, sin traer miles de señales de una sola vez.
  Future<ChannelCatalogPage> fetchPublicChannelPage({
    String search = '',
    int offset = 0,
  }) async {
    final normalizedOffset = offset.clamp(0, 100000).toInt();
    final query = <String, String>{
      'offset': normalizedOffset.toString(),
      if (search.trim().isNotEmpty) 'q': search.trim(),
    };
    final uri = Uri.parse(_baseUrl + '/api/channels').replace(
      queryParameters: query,
    );
    final result = await _client.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    final payload = _decode(result);
    final rows = payload['channels'];
    if (rows is! List) {
      throw const ChannelCatalogException(
        'El servidor no devolvió un catálogo de canales válido.',
      );
    }
    final page = rows
        .whereType<Map>()
        .map((row) => SportsChannel.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
    final responseOffset = int.tryParse(
          (payload['offset'] ?? normalizedOffset).toString(),
        ) ??
        normalizedOffset;
    final total = int.tryParse(
          (payload['total'] ?? (responseOffset + page.length)).toString(),
        ) ??
        responseOffset + page.length;
    final hasMore = page.isNotEmpty &&
        (payload.containsKey('hasMore')
            ? payload['hasMore'] == true
            : responseOffset + page.length < total);
    return ChannelCatalogPage(
      channels: page,
      total: total,
      offset: responseOffset,
      hasMore: hasMore,
    );
  }

  /// Compatibilidad para llamadas antiguas: devuelve la primera página.
  Future<List<SportsChannel>> fetchPublicChannels() async {
    return (await fetchPublicChannelPage()).channels;
  }

  Future<List<SportsChannel>> fetchAdminChannels({
    String search = '',
    int offset = 0,
  }) async {
    final uri = Uri.parse(_baseUrl + '/api/channels/admin/catalog').replace(
      queryParameters: <String, String>{
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'offset': offset.toString(),
      },
    );
    final result = await _client.get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 20));
    final payload = _decode(result);
    final rows = payload['channels'];
    if (rows is! List) return <SportsChannel>[];
    return rows
        .whereType<Map>()
        .map((row) => SportsChannel.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  Future<List<ChannelPlaylistSource>> fetchSources() async {
    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/channels/admin/sources'),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    final rows = _decode(result)['sources'];
    if (rows is! List) return <ChannelPlaylistSource>[];
    return rows
        .whereType<Map>()
        .map((row) => ChannelPlaylistSource.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  Future<void> addPlaylist({
    required String url,
    required String label,
  }) async {
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/sources'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'url': url.trim(),
        'label': label.trim().isEmpty ? 'Lista IPTV' : label.trim(),
      }),
    ).timeout(const Duration(seconds: 25));
    _decode(result);
  }

  Future<void> refreshSources() async {
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/refresh'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: '{}',
    ).timeout(const Duration(seconds: 25));
    _decode(result);
  }

  Future<void> setVisibility(
    String channelId, {
    required bool visible,
  }) async {
    final encodedId = Uri.encodeComponent(channelId);
    final result = await _client.patch(
      Uri.parse(_baseUrl + '/api/channels/admin/channels/' +
          encodedId + '/visibility'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, bool>{'visible': visible}),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }

  Future<void> setLanguage(
    String channelId, {
    required String language,
  }) async {
    if (!const <String>{'es', 'en', 'unknown'}.contains(language)) {
      throw ArgumentError.value(language, 'language', 'Idioma no válido.');
    }
    final encodedId = Uri.encodeComponent(channelId);
    final result = await _client.patch(
      Uri.parse(_baseUrl + '/api/channels/admin/channels/' +
          encodedId + '/language'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'language': language}),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }

  Future<Set<String>> fetchFavorites() async {
    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/channels/favorites'),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    final rows = _decode(result)['channelIds'];
    if (rows is! List) return <String>{};
    return rows.map((id) => id.toString()).toSet();
  }

  Future<void> saveFavorites(Set<String> channelIds) async {
    final result = await _client.put(
      Uri.parse(_baseUrl + '/api/channels/favorites'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'channelIds': channelIds.toList(growable: false),
      }),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }
}

final ChannelCatalogService channelCatalogService = ChannelCatalogService();
