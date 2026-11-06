import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'live_media_format.dart';
import 'sports_api_service.dart';

const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

/// Etiqueta compacta que se muestra en las tarjetas de los canales.
/// Los canales sin idioma confirmado no reciben una bandera inventada.
String? channelLanguageDisplayLabel(String language) {
  switch (language.trim().toLowerCase()) {
    case 'es':
      return 'IDIOMA 🇪🇸';
    case 'en':
      return 'IDIOMA 🇺🇸';
    default:
      return null;
  }
}

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
    if (liveMediaFormatForUrl(url) == null) {
      throw const FormatException(
        'El canal no contiene una señal HLS, DASH, Smooth Streaming o vídeo directo compatible.',
      );
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
    this.format = '',
    this.lastError = '',
    this.importedCount = 0,
    this.lastImportedAt = '',
  });

  final String id;
  final String url;
  final String label;
  final String status;
  final String format;
  final String lastError;
  final int importedCount;
  final String lastImportedAt;

  factory ChannelPlaylistSource.fromJson(Map<String, dynamic> json) {
    return ChannelPlaylistSource(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      label: (json['label'] ?? 'Lista IPTV').toString(),
      status: (json['status'] ?? 'queued').toString(),
      format: (json['format'] ?? '').toString(),
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

class AppLicenseStatus {
  const AppLicenseStatus({
    required this.allowed,
    required this.status,
    required this.licenseType,
    required this.email,
  });

  final bool allowed;
  final String status;
  final String licenseType;
  final String email;

  factory AppLicenseStatus.fromJson(Map<String, dynamic> json) {
    return AppLicenseStatus(
      allowed: json['allowed'] == true,
      status: (json['status'] ?? 'unknown').toString(),
      licenseType: (json['licenseType'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}

class AppLicenseRecord {
  const AppLicenseRecord({
    required this.email,
    required this.licenseType,
    required this.status,
    this.note = '',
    this.grantedAt = '',
    this.grantedBy = '',
  });

  final String email;
  final String licenseType;
  final String status;
  final String note;
  final String grantedAt;
  final String grantedBy;

  factory AppLicenseRecord.fromJson(Map<String, dynamic> json) {
    return AppLicenseRecord(
      email: (json['email'] ?? '').toString(),
      licenseType: (json['license_type'] ?? json['licenseType'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      note: (json['note'] ?? '').toString(),
      grantedAt: (json['granted_at'] ?? json['grantedAt'] ?? '').toString(),
      grantedBy: (json['granted_by'] ?? json['grantedBy'] ?? '').toString(),
    );
  }
}

class ChannelCatalogService {
  ChannelCatalogService({
    http.Client? client,
    String? googleServerClientId,
    String? Function()? accessTokenProvider,
  })  : _client = client ?? http.Client(),
        _serverClientId = googleServerClientId ?? _googleServerClientId,
        _accessTokenProvider = accessTokenProvider;

  final http.Client _client;
  final String _serverClientId;
  // Inyectable para pruebas e integraciones que ya gestionen un token.
  // El Worker siempre verifica el ID token de Google antes de autorizar.
  final String? Function()? _accessTokenProvider;
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
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
  }

  /// Comprueba antes de abrir Google que el cliente Web de la APK y el
  /// configurado en Cloudflare sean exactamente el mismo. El ID OAuth es
  /// público por diseño; no se devuelve ningún secreto ni token.
  Future<void> validateGoogleOAuthConfiguration() async {
    if (_serverClientId.isEmpty) {
      throw const ChannelCatalogException(
        'Falta GOOGLE_OAUTH_CLIENT_ID (cliente OAuth Web) en la APK.',
      );
    }

    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/channels/auth-config'),
      headers: const <String, String>{'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));
    final payload = _decode(result);
    if (payload['configured'] != true) {
      throw const ChannelCatalogException(
        'Google OAuth no está configurado en Cloudflare. Revisa el secreto GOOGLE_OAUTH_CLIENT_ID del Worker.',
      );
    }
    final workerClientId = (payload['clientId'] ?? '').toString().trim();
    if (workerClientId.isEmpty || workerClientId != _serverClientId) {
      throw const ChannelCatalogException(
        'La APK y Cloudflare usan clientes OAuth Web diferentes. Configura el mismo GOOGLE_OAUTH_CLIENT_ID en ambos repositorios y vuelve a compilar.',
      );
    }
  }

  /// Recupera una cuenta de Google ya autorizada sin forzar una nueva
  /// selección. El SDK puede devolver null cuando no existe una sesión
  /// ligera disponible; en ese caso la pantalla conserva el botón de acceso.
  Future<String?> restoreSession() async {
    final currentToken = _idToken;
    final currentEmail = signedInEmail;
    if (currentToken != null && currentToken.isNotEmpty &&
        currentEmail != null && currentEmail.isNotEmpty) {
      return currentEmail;
    }

    await validateGoogleOAuthConfiguration();
    await _initializeGoogle();

    try {
      final Future<GoogleSignInAccount?>? attempt =
          _google.attemptLightweightAuthentication();
      if (attempt == null) return null;
      final account = await attempt;
      if (account == null) return null;
      return _rememberGoogleAccount(account);
    } on GoogleSignInException {
      // La recuperación ligera nunca debe bloquear el acceso manual.
      _idToken = null;
      signedInEmail = null;
      return null;
    }
  }

  String _rememberGoogleAccount(GoogleSignInAccount account) {
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const ChannelCatalogException(
        'Google no entregó un ID token. Comprueba el cliente OAuth Web.',
      );
    }
    _idToken = token;
    signedInEmail = account.email;
    return account.email;
  }

  Future<String> signIn() async {
    // Primero intenta recuperar la sesión previa. No ejecutar signOut aquí:
    // hacerlo elimina la autorización que permitiría reutilizar la cuenta.
    final restoredEmail = await restoreSession();
    if (restoredEmail != null) return restoredEmail;

    if (!_google.supportsAuthenticate()) {
      throw const ChannelCatalogException(
        'El inicio de sesión Google no está disponible en este dispositivo.',
      );
    }
    try {
      final account = await _google.authenticate();
      return _rememberGoogleAccount(account);
    } on GoogleSignInException catch (error) {
      _idToken = null;
      signedInEmail = null;

      final detail = error.description?.trim();
      final detailSuffix = detail == null || detail.isEmpty
          ? ''
          : '\nDetalle de Google: ' + detail;
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
          throw ChannelCatalogException(
            'Google rechazó la configuración OAuth. Revisa el package name com.example.deporte_total_360, la huella SHA-1 de esta APK y que serverClientId sea el cliente OAuth Web.' + detailSuffix,
          );
        case GoogleSignInExceptionCode.canceled:
          throw ChannelCatalogException(
            'Google canceló el acceso. Si ocurrió justo después de elegir tu cuenta, suele indicar que el SHA-1, el package name o el cliente OAuth Web no coinciden.' + detailSuffix,
          );
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw ChannelCatalogException(
            'El servicio de identidad de Google no está disponible o está mal configurado en este dispositivo.' + detailSuffix,
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          throw ChannelCatalogException(
            'Android no pudo abrir la ventana segura de Google. Cierra y vuelve a abrir la aplicación.' + detailSuffix,
          );
        default:
          throw ChannelCatalogException(
            'No se pudo iniciar sesión con Google (código: ' + error.code.name + ').' + detailSuffix,
          );
      }
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
    final token = _idToken ?? _accessTokenProvider?.call();
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
    int limit = 200,
  }) async {
    final normalizedOffset = offset.clamp(0, 100000).toInt();
    final normalizedLimit = limit.clamp(1, 2000).toInt();
    final query = <String, String>{
      'offset': normalizedOffset.toString(),
      'limit': normalizedLimit.toString(),
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

  /// Devuelve página y total real del catálogo privado; el total no depende
  /// de cuántos registros haya cargado la interfaz en memoria.
  Future<ChannelCatalogPage> fetchAdminChannelPage({
    String search = '',
    int offset = 0,
  }) async {
    final normalizedOffset = offset.clamp(0, 100000).toInt();
    final uri = Uri.parse(_baseUrl + '/api/channels/admin/catalog').replace(
      queryParameters: <String, String>{
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'offset': normalizedOffset.toString(),
      },
    );
    final result = await _client.get(uri, headers: _authHeaders())
        .timeout(const Duration(seconds: 25));
    final payload = _decode(result);
    final rows = payload['channels'];
    if (rows is! List) {
      throw const ChannelCatalogException(
        'El servidor no devolvió un catálogo privado válido.',
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
    final hasMore = payload['hasMore'] == true ||
        responseOffset + page.length < total;
    return ChannelCatalogPage(
      channels: page,
      total: total,
      offset: responseOffset,
      hasMore: hasMore,
    );
  }

  /// Compatibilidad con pantallas antiguas que solo necesitan la primera
  /// página; no cambia la firma pública ya utilizada por el resto de la APK.
  Future<List<SportsChannel>> fetchAdminChannels({
    String search = '',
    int offset = 0,
  }) async {
    return (await fetchAdminChannelPage(
      search: search,
      offset: offset,
    )).channels;
  }

  /// Diagnóstico de conectividad. Un HTTP 403 puede ser geobloqueo,
  /// autenticación o política del proveedor; no se presenta como certeza.
  Future<String> diagnoseStream(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || liveMediaFormatForUrl(value) == null) {
      return 'ENLACE NO COMPATIBLE: revisa la URL o el formato de la señal.';
    }
    try {
      final result = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': '*/*',
          'Range': 'bytes=0-2047',
        },
      ).timeout(const Duration(seconds: 10));
      switch (result.statusCode) {
        case 200:
        case 206:
          return 'RESPONDE: el servidor permite la conexión inicial. La reproducción todavía depende del reproductor y de los segmentos.';
        case 401:
          return 'ACCESO DENEGADO (401): el proveedor requiere credenciales o autorización.';
        case 403:
          return 'ACCESO DENEGADO (403): posible restricción regional, permisos o bloqueo del proveedor. No se puede confirmar que sea GeoIP solo con este código.';
        case 404:
          return 'FUENTE NO ENCONTRADA (404): el enlace puede haber caducado o haber sido retirado.';
        case 451:
          return 'RESTRICCIÓN LEGAL O REGIONAL (451): el proveedor limita esta transmisión.';
        case 429:
          return 'LÍMITE DEL PROVEEDOR (429): espera y vuelve a intentarlo más tarde.';
        default:
          if (result.statusCode >= 500) {
            return 'SERVIDOR NO DISPONIBLE (' + result.statusCode.toString() + '): prueba más tarde o utiliza una fuente autorizada alternativa.';
          }
          return 'RESPUESTA HTTP ' + result.statusCode.toString() + ': revisa la fuente con el proveedor.';
      }
    } on Exception catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('timeout')) {
        return 'TIEMPO AGOTADO: el servidor no respondió a tiempo.';
      }
      return 'NO SE PUDO CONECTAR: comprueba Internet, la fuente y vuelve a probar.';
    }
  }

  /// Comprueba la licencia comercial o el pase gratuito de la cuenta Google
  /// actual. El servidor decide el acceso; no se confía en datos locales.
  Future<AppLicenseStatus> fetchAppLicenseStatus() async {
    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/license'),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 15));
    final payload = _decode(result);
    return AppLicenseStatus.fromJson(payload);
  }

  Future<List<AppLicenseRecord>> fetchAdminLicenses() async {
    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/channels/admin/licenses'),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    final rows = _decode(result)['licenses'];
    if (rows is! List) return <AppLicenseRecord>[];
    return rows
        .whereType<Map>()
        .map((row) => AppLicenseRecord.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  Future<void> grantAppLicense({
    required String email,
    required String licenseType,
    String note = '',
  }) async {
    if (!const <String>{'paid', 'free'}.contains(licenseType)) {
      throw ArgumentError.value(licenseType, 'licenseType');
    }
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/licenses'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email.trim().toLowerCase(),
        'licenseType': licenseType,
        'note': note.trim(),
      }),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }

  Future<void> revokeAppLicense({required String email}) async {
    final result = await _client.patch(
      Uri.parse(_baseUrl + '/api/channels/admin/licenses/revoke'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email.trim().toLowerCase(),
      }),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
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

  /// Retira una fuente de la cola de actualización. Los canales que ya fueron
  /// importados permanecen disponibles en el catálogo para publicarlos o
  /// volverlos a ocultar individualmente.
  Future<void> deletePlaylistSource({required String id}) async {
    final safeId = id.trim();
    if (safeId.isEmpty) {
      throw const ChannelCatalogException('El identificador de la lista no es válido.');
    }
    final result = await _client.delete(
      Uri.parse(_baseUrl + '/api/channels/admin/sources/' +
          Uri.encodeComponent(safeId)),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }

  /// Vuelve a poner en cola una lista que falló durante la importación.
  Future<void> retryPlaylistSource({required String id}) async {
    final safeId = id.trim();
    if (safeId.isEmpty) {
      throw const ChannelCatalogException('El identificador de la lista no es válido.');
    }
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/sources/' +
          Uri.encodeComponent(safeId) + '/retry'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: '{}',
    ).timeout(const Duration(seconds: 20));
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
