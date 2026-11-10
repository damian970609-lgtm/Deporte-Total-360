import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'live_media_format.dart';
import 'sports_api_service.dart';

const int channelCatalogMaxOffset = 5000000;
const int channelAdminCatalogPageSize = 2000;

/// Copia persistente del catálogo deportivo que ya se descargó correctamente.
/// Se conserva en el dispositivo y no depende de que Cloudflare siga disponible.
const String channelCatalogSnapshotCacheKey =
    'dt360_channel_catalog_snapshot_v1';
const int maxCachedChannelCatalogEntries = 2000;
/// El inventario privado completo se conserva en archivos locales, hasta 20.000 canales.
const int maxAdminCachedChannelCatalogEntries = 20000;

Future<List<SportsChannel>> loadCachedVisibleSportsChannels() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(channelCatalogSnapshotCacheKey);
  if (raw == null || raw.isEmpty) return <SportsChannel>[];

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <SportsChannel>[];
    final byId = <String, SportsChannel>{};
    for (final row in decoded.whereType<Map>()) {
      try {
        final channel = SportsChannel.fromJson(
          Map<String, dynamic>.from(row),
        );
        if (channel.isSports && channel.visible) {
          byId[channel.id] = channel;
        }
      } on FormatException {
        // Una fila dañada no debe inutilizar toda la copia local.
      }
    }
    return byId.values.take(maxCachedChannelCatalogEntries).toList(
      growable: false,
    );
  } catch (_) {
    return <SportsChannel>[];
  }
}

const String channelCatalogSnapshotSavedAtKey =
    'dt360_channel_catalog_snapshot_saved_at_v1';

Future<bool> isCachedPublicChannelSnapshotFresh({
  Duration maxAge = const Duration(minutes: 15),
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.tryParse(
      prefs.getString(channelCatalogSnapshotSavedAtKey) ?? '',
    );
    if (savedAt == null) return false;
    final age = DateTime.now().difference(savedAt);
    return !age.isNegative && age <= maxAge;
  } catch (_) {
    return false;
  }
}

Future<void> saveCachedPublicChannelSnapshot(
  Iterable<SportsChannel> channels,
) async {
  final prefs = await SharedPreferences.getInstance();
  final byId = <String, SportsChannel>{};
  for (final channel in channels) {
    byId[channel.id] = channel;
  }
  final snapshot = byId.values
      .take(maxCachedChannelCatalogEntries)
      .map((channel) => channel.toJson())
      .toList(growable: false);
  await prefs.setString(channelCatalogSnapshotCacheKey, jsonEncode(snapshot));
  await prefs.setString(
    channelCatalogSnapshotSavedAtKey,
    DateTime.now().toIso8601String(),
  );
}

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
    this.tvgId = '',
    this.searchAliases = const <String>[],
  });

  final String id;
  final String identifier;
  final String tvgId;
  final String name;
  final String url;
  final String logoUrl;
  final String groupTitle;
  final bool isSports;
  final bool visible;
  final String language;
  final List<String> searchAliases;

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'identifier': identifier,
        'tvgId': tvgId,
        'name': name,
        'url': url,
        'logoUrl': logoUrl,
        'groupTitle': groupTitle,
        'isSports': isSports,
        'visible': visible,
        'language': language,
        'searchAliases': searchAliases,
      };

  factory SportsChannel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['identifier'] ?? '').toString().trim();
    final identifier =
        (json['identifier'] ?? json['id'] ?? '').toString().trim();
    final tvgId = (json['tvgId'] ?? json['tvg_id'] ?? '').toString().trim();
    final url = (json['url'] ?? '').toString().trim();
    final logoUrl =
        (json['logoUrl'] ?? json['logo_url'] ?? '').toString().trim();
    final groupTitle =
        (json['groupTitle'] ?? json['group_title'] ?? '').toString().trim();

    final aliases = <String>[];
    void addAlias(dynamic value) {
      if (value is String) {
        for (final item in value.split(RegExp(r'[,;|]'))) {
          final candidate = item.trim();
          if (candidate.isNotEmpty && !aliases.contains(candidate)) {
            aliases.add(candidate);
          }
        }
      } else if (value is List) {
        for (final item in value) {
          addAlias(item);
        }
      }
    }

    for (final key in <String>[
      'searchAliases',
      'search_aliases',
      'aliases',
      'alternateNames',
      'alternate_names',
      'keywords',
      'searchTerms',
      'search_terms',
      'tvgName',
      'tvg_name',
      'channelName',
      'channel_name',
      'displayName',
      'display_name',
      'slug',
      'sourceLabel',
      'source_label',
      'playlistName',
      'playlist_name',
      'providerName',
      'provider_name',
      'category',
      'categoryName',
      'category_name',
      'rawName',
      'raw_name',
    ]) {
      addAlias(json[key]);
    }

    final explicitName = (json['name'] ?? '').toString().trim();
    final placeholderName = const <String>{
      '',
      'null',
      'unknown',
      'unnamed',
      'n/a',
      'na',
      '-',
      '--',
      'sin nombre',
      'señal sin nombre',
      'channel',
      'canal',
    }.contains(explicitName.toLowerCase());

    final fallbackName = <String>[
      (json['displayName'] ?? json['display_name'] ?? '').toString().trim(),
      (json['channelName'] ?? json['channel_name'] ?? '').toString().trim(),
      (json['tvgName'] ?? json['tvg_name'] ?? '').toString().trim(),
      if (aliases.isNotEmpty) aliases.first,
      tvgId,
    ].firstWhere((value) => value.isNotEmpty, orElse: () {
      final segments = Uri.tryParse(url)?.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false);
      final tail =
          segments != null && segments.isNotEmpty ? segments.last : '';
      final withoutExtension =
          tail.replaceFirst(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final slug = withoutExtension
          .replaceAll(RegExp(r'[-_.]+'), ' ')
          .trim();
      if (slug.isNotEmpty) return slug;
      return id.isEmpty ? 'Señal sin nombre' : 'Señal sin nombre · $id';
    });
    final name = placeholderName ? fallbackName : explicitName;

    if (name.isNotEmpty && !aliases.contains(name)) {
      aliases.insert(0, name);
    }
    for (final value in <String>[id, identifier, tvgId, groupTitle]) {
      if (value.isNotEmpty && !aliases.contains(value)) {
        aliases.add(value);
      }
    }

    final rawLanguage =
        (json['language'] ?? 'unknown').toString().trim().toLowerCase();
    final language = const <String>{'es', 'en'}.contains(rawLanguage)
        ? rawLanguage
        : 'unknown';

    if (id.isEmpty || identifier.isEmpty || url.isEmpty) {
      throw const FormatException('El canal recibido está incompleto.');
    }
    if (!isSupportedChannelPlaybackUrl(url)) {
      throw const FormatException(
        'El canal no contiene una señal HTTPS directa HLS, DASH, Smooth Streaming o de vídeo progresivo compatible.',
      );
    }

    return SportsChannel(
      id: id,
      identifier: identifier,
      tvgId: tvgId,
      name: name,
      url: url,
      logoUrl: logoUrl,
      groupTitle: groupTitle,
      isSports: json['isSports'] == true,
      visible: json['visible'] == true,
      language: language,
      searchAliases: List<String>.unmodifiable(aliases),
    );
  }
}

/// Normalizes accents and punctuation so provider IDs such as ESPN.2 and
/// searches such as "ESPN 2" match each other.
String _normalizeChannelSearchText(String value) {
  var normalized = value.toLowerCase();
  const replacements = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
  };
  replacements.forEach((from, to) => normalized = normalized.replaceAll(from, to));
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

bool matchesSportsChannelSearch(SportsChannel channel, String query) {
  final normalizedQuery = _normalizeChannelSearchText(query);
  if (normalizedQuery.isEmpty) return true;
  final uri = Uri.tryParse(channel.url);
  final urlMetadata =
      uri == null ? '' : '${uri.host} ${uri.pathSegments.join(' ')}';
  final searchable = _normalizeChannelSearchText(<String>[
    channel.name,
    channel.identifier,
    channel.id,
    channel.tvgId,
    channel.groupTitle,
    channel.logoUrl,
    urlMetadata,
    ...channel.searchAliases,
  ].join(' '));
  return normalizedQuery
      .split(' ')
      .where((term) => term.isNotEmpty)
      .every(searchable.contains);
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

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'url': url,
        'label': label,
        'status': status,
        'format': format,
        'last_error': lastError,
        'imported_count': importedCount,
        'last_imported_at': lastImportedAt,
      };

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


/// Snapshot local, separado por cuenta, para que un fallo parcial de Cloudflare
/// no borre las fuentes o los canales que sí se descargaron correctamente.
class ChannelAdminSnapshot {
  const ChannelAdminSnapshot({
    required this.email,
    required this.savedAt,
    required this.channels,
    required this.sources,
    required this.hasChannels,
    required this.hasSources,
  });

  final String email;
  final String savedAt;
  final List<SportsChannel> channels;
  final List<ChannelPlaylistSource> sources;
  final bool hasChannels;
  final bool hasSources;
}

class ChannelAdminSnapshotStore {
  static const String _keyPrefix = 'dt360_admin_snapshot_v1_';
  static const String _folderName = 'dt360_admin_snapshots';
  static final Map<String, Future<void>> _pendingWrites =
      <String, Future<void>>{};

  static String _cacheKey(String normalizedEmail) {
    final account = base64Url
        .encode(utf8.encode(normalizedEmail))
        .replaceAll('=', '');
    return '$_keyPrefix$account';
  }

  static String _accountFileName(String normalizedEmail) {
    final account = base64Url
        .encode(utf8.encode(normalizedEmail))
        .replaceAll('=', '');
    return 'admin_$account.json';
  }

  static Future<File?> _fileForAccount(String normalizedEmail) async {
    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/$_folderName');
      await directory.create(recursive: true);
      return File('${directory.path}/${_accountFileName(normalizedEmail)}');
    } catch (_) {
      // En pruebas sin plataforma de archivos, usa SharedPreferences.
      return null;
    }
  }

  static Future<String?> _readRaw(String normalizedEmail) async {
    final file = await _fileForAccount(normalizedEmail);
    if (file != null) {
      try {
        if (await file.exists()) return await file.readAsString();
      } catch (_) {
        // Intenta la copia de migración de SharedPreferences.
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(normalizedEmail));
      if (raw == null || raw.isEmpty) return null;
      if (file != null) {
        try {
          await _writeFile(file, raw);
          await prefs.remove(_cacheKey(normalizedEmail));
        } catch (_) {}
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeFile(File file, String raw) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(raw, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  static Future<void> _writeRaw(String normalizedEmail, String raw) async {
    final file = await _fileForAccount(normalizedEmail);
    if (file != null) {
      try {
        await _writeFile(file, raw);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_cacheKey(normalizedEmail));
        } catch (_) {}
        return;
      } catch (_) {
        // No pierdas la copia si el almacenamiento de archivos no está disponible.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(normalizedEmail), raw);
  }

  static Future<ChannelAdminSnapshot?> load({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    try {
      final raw = await _readRaw(normalizedEmail);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          (decoded['email'] ?? '').toString().trim().toLowerCase() !=
              normalizedEmail) {
        return null;
      }

      final channelRows = decoded['channels'];
      final sourceRows = decoded['sources'];
      final channels = <SportsChannel>[];
      if (channelRows is List) {
        for (final row in channelRows.whereType<Map>()) {
          try {
            channels.add(
              SportsChannel.fromJson(Map<String, dynamic>.from(row)),
            );
          } on FormatException {
            // Una fila dañada no debe borrar las demás.
          }
        }
      }

      final sources = <ChannelPlaylistSource>[];
      if (sourceRows is List) {
        for (final row in sourceRows.whereType<Map>()) {
          try {
            sources.add(
              ChannelPlaylistSource.fromJson(
                Map<String, dynamic>.from(row),
              ),
            );
          } on FormatException {
            // Conserva las fuentes válidas aunque una fila esté dañada.
          }
        }
      }

      return ChannelAdminSnapshot(
        email: normalizedEmail,
        savedAt: (decoded['savedAt'] ?? '').toString(),
        channels: channels
            .take(maxAdminCachedChannelCatalogEntries)
            .toList(growable: false),
        sources: sources.toList(growable: false),
        hasChannels: channelRows is List,
        hasSources: sourceRows is List,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required String email,
    List<SportsChannel>? channels,
    List<ChannelPlaylistSource>? sources,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || (channels == null && sources == null)) {
      return;
    }

    final key = _cacheKey(normalizedEmail);
    final previousWrite = _pendingWrites[key] ?? Future<void>.value();
    final operation = previousWrite.catchError((Object _) {}).then<void>(
      (_) async {
        Map<String, dynamic> previous = <String, dynamic>{};
        final raw = await _readRaw(normalizedEmail);
        if (raw != null && raw.isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map &&
                (decoded['email'] ?? '').toString().trim().toLowerCase() ==
                    normalizedEmail) {
              previous = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            // Una copia dañada se reemplaza con la información disponible.
          }
        }

        final updated = jsonEncode(<String, Object>{
          'email': normalizedEmail,
          'savedAt': DateTime.now().toIso8601String(),
          'channels': channels == null
              ? (previous['channels'] is List
                  ? previous['channels'] as List
                  : <Object>[])
              : channels
                  .take(maxAdminCachedChannelCatalogEntries)
                  .map((channel) => channel.toJson())
                  .toList(growable: false),
          'sources': sources == null
              ? (previous['sources'] is List
                  ? previous['sources'] as List
                  : <Object>[])
              : sources
                  .map((source) => source.toJson())
                  .toList(growable: false),
        });
        await _writeRaw(normalizedEmail, updated);
      },
    );
    _pendingWrites[key] = operation;

    try {
      await operation;
    } finally {
      if (identical(_pendingWrites[key], operation)) {
        _pendingWrites.remove(key);
      }
    }
  }
}

class ChannelCatalogPage {
  const ChannelCatalogPage({
    required this.channels,
    required this.total,
    required this.offset,
    required this.hasMore,
    this.totalIsEstimate = false,
  });

  final List<SportsChannel> channels;
  final int total;
  final int offset;
  final bool hasMore;
  final bool totalIsEstimate;
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

  Future<void> _initializeGoogle() async {
    final pending = _initialization ??= _google.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    try {
      await pending;
    } catch (_) {
      if (identical(_initialization, pending)) _initialization = null;
      rethrow;
    }
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

  /// Recupera una cuenta de Google sin abrir un selector de cuentas.
  /// No consulta Cloudflare: restaurar la identidad local no debe consumir
  /// cuota del Worker ni depender de que el backend esté disponible.
  Future<String?> _restoreGoogleAccount() async {
    await _initializeGoogle();
    try {
      final attempt = _google.attemptLightweightAuthentication();
      if (attempt == null) return null;
      final account = await attempt;
      if (account == null) return null;
      return _rememberGoogleAccount(account);
    } on GoogleSignInException {
      _idToken = null;
      signedInEmail = null;
      return null;
    }
  }

  /// Recupera el token local si sigue vigente y lo renueva mediante Google
  /// Credential Manager cuando caducó o está cerca de caducar.
  Future<String?> restoreSession() async {
    final currentToken = _idToken;
    final currentEmail = signedInEmail;
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        currentEmail != null &&
        currentEmail.isNotEmpty &&
        !_tokenNeedsRefresh(currentToken)) {
      return currentEmail;
    }

    _idToken = null;
    signedInEmail = null;
    return _restoreGoogleAccount();
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

    // La comprobación OAuth solo se necesita antes de un acceso interactivo.
    // Restaurar la sesión local no debe consumir cuota del Worker.
    try {
      await validateGoogleOAuthConfiguration();
    } catch (_) {
      // Google y el backend validarán el token al ejecutar la operación.
    }

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

  Future<Map<String, String>> _freshAuthHeaders() async {
    if (_accessTokenProvider != null) return _authHeaders();

    final token = _idToken;
    if (token == null || token.isEmpty || _tokenNeedsRefresh(token)) {
      _idToken = null;
      signedInEmail = null;
      final restored = await _restoreGoogleAccount();
      if (restored == null || _idToken == null || _idToken!.isEmpty) {
        throw const ChannelCatalogException(
          'No se pudo recuperar tu sesión Google. Entra una vez con la misma cuenta y vuelve a intentarlo.',
        );
      }
    }
    return _authHeaders();
  }

  /// Repite una sola vez una operación administrativa tras recuperar la
  /// sesión Google cuando Cloudflare devuelve HTTP 401.
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final firstHeaders = await _freshAuthHeaders();
    final firstResponse = await send(firstHeaders);
    if (firstResponse.statusCode != 401) return firstResponse;

    if (_accessTokenProvider != null) {
      final refreshedHeaders = _authHeaders();
      if (refreshedHeaders['Authorization'] ==
          firstHeaders['Authorization']) {
        return firstResponse;
      }
      return send(refreshedHeaders);
    }

    _idToken = null;
    signedInEmail = null;
    final restored = await _restoreGoogleAccount();
    if (restored == null || _idToken == null || _idToken!.isEmpty) {
      return firstResponse;
    }
    return send(_authHeaders());
  }

  static const String _trialDeviceKey = 'dt360_vip_trial_device_v1';
  static const String _trialSessionKey = 'dt360_vip_trial_session_v1';

  Future<String> _getTrialDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString(_trialDeviceKey) ?? '').trim().toLowerCase();
    if (RegExp(r'^[a-f0-9]{64}$').hasMatch(saved)) return saved;
    final random = math.Random.secure();
    final generated = List<int>.generate(
      32,
      (_) => random.nextInt(256),
      growable: false,
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_trialDeviceKey, generated);
    return generated;
  }

  Future<Map<String, String>?> trialSessionHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString(_trialSessionKey) ?? '').trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) return null;
    final deviceId = await _getTrialDeviceId();
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ' + token,
      'X-DT360-Device-ID': deviceId,
    };
  }

  Future<Map<String, String>> userAuthorizationHeaders() async {
    if (_accessTokenProvider != null) return _authHeaders();
    final trialHeaders = await trialSessionHeaders();
    return trialHeaders ?? _authHeaders();
  }

  Future<bool> validateTrialSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString(_trialSessionKey) ?? '').trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) return false;
    final deviceId = await _getTrialDeviceId();
    try {
      final result = await _client.post(
        Uri.parse(_baseUrl + '/api/trials/check'),
        headers: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'sessionToken': token,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 12));
      final payload = _decode(result);
      final allowed = payload['allowed'] == true;
      if (!allowed) await prefs.remove(_trialSessionKey);
      return allowed;
    } catch (_) {
      return false;
    }
  }

  Future<void> redeemTrialCode(String code) async {
    final normalized = code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (!RegExp(r'^[A-F0-9]{16,40}$').hasMatch(normalized)) {
      throw const ChannelCatalogException('Introduce un código VIP válido.');
    }
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getTrialDeviceId();
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/trials/redeem'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'code': normalized,
        'deviceId': deviceId,
      }),
    ).timeout(const Duration(seconds: 20));
    final payload = _decode(result);
    final token = (payload['sessionToken'] ?? '').toString().trim().toLowerCase();
    if (payload['activated'] != true ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const ChannelCatalogException(
        'Cloudflare no confirmó la activación del código VIP.',
      );
    }
    await prefs.setString(_trialSessionKey, token);
  }

  Future<void> clearTrialSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trialSessionKey);
  }

  Future<Map<String, dynamic>> fetchTrialPassSummary() async {
    final result = await _client.get(
      Uri.parse(_baseUrl + '/api/channels/admin/trials'),
      headers: _authHeaders(),
    ).timeout(const Duration(seconds: 20));
    return _decode(result);
  }

  Future<List<String>> generateTrialPassCodes({int count = 10}) async {
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/trials'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, int>{'count': count.clamp(1, 10).toInt()}),
    ).timeout(const Duration(seconds: 20));
    final payload = _decode(result);
    final rows = payload['codes'];
    if (rows is! List) return <String>[];
    return rows.map((value) => value.toString()).toList(growable: false);
  }


  bool _tokenNeedsRefresh(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return true;
      final expiresAt = int.tryParse((payload['exp'] ?? '').toString());
      if (expiresAt == null) return true;
      return expiresAt <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120;
    } catch (_) {
      return true;
    }
  }

  /// Encabezados de Chat con sesión Google fresca. Se reutiliza la identidad
  /// ya verificada por la puerta de licencias de la aplicación y se renueva
  /// en segundo plano cuando el ID token está próximo a caducar.
  Future<Map<String, String>> chatAuthorizationHeaders() async {
    if (_accessTokenProvider != null) return _authHeaders();
    final trialHeaders = await trialSessionHeaders();
    if (trialHeaders != null) return trialHeaders;

    final token = _idToken;
    if (token == null || token.isEmpty || _tokenNeedsRefresh(token)) {
      _idToken = null;
      signedInEmail = null;
      final restoredEmail = await restoreSession();
      if (restoredEmail == null) {
        throw const ChannelCatalogException(
          'Tu sesión Google caducó. Activa un pase VIP o vuelve a iniciar sesión para usar el Chat.',
        );
      }
    }
    return _authHeaders();
  }

  /// Descarga solo una página del catálogo. La interfaz solicita las
  /// siguientes al desplazarse, sin traer miles de señales de una sola vez.
  Future<ChannelCatalogPage> fetchPublicChannelPage({
    String search = '',
    int offset = 0,
    int limit = 200,
  }) async {
    final normalizedOffset = offset.clamp(0, channelCatalogMaxOffset).toInt();
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
      totalIsEstimate: payload['totalIsEstimate'] == true,
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
    int limit = 200,
  }) async {
    final normalizedOffset = offset.clamp(0, channelCatalogMaxOffset).toInt();
    final normalizedLimit = limit.clamp(1, channelAdminCatalogPageSize).toInt();
    final uri = Uri.parse(_baseUrl + '/api/channels/admin/catalog').replace(
      queryParameters: <String, String>{
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'offset': normalizedOffset.toString(),
        'limit': normalizedLimit.toString(),
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
      totalIsEstimate: payload['totalIsEstimate'] == true,
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
    if (uri == null || !isSupportedChannelPlaybackUrl(value)) {
      return 'ENLACE NO COMPATIBLE: se necesita una URL HTTPS directa con formato multimedia admitido.';
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
    if (rows is! List) {
      throw const ChannelCatalogException(
        'Cloudflare no devolvió la lista de fuentes con un formato válido.',
      );
    }
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

  Future<void> updatePlaylistSource({
    required String id,
    required String url,
    required String label,
  }) async {
    final safeId = id.trim();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(safeId)) {
      throw const ChannelCatalogException(
        'El identificador de la lista no es válido.',
      );
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ChannelCatalogException(
        'Introduce una URL HTTPS pública válida.',
      );
    }
    if (label.trim().isEmpty || label.trim().length > 80) {
      throw const ChannelCatalogException(
        'El nombre de la lista debe tener entre 1 y 80 caracteres.',
      );
    }
    final result = await _client.put(
      Uri.parse(_baseUrl + '/api/channels/admin/sources/' +
          Uri.encodeComponent(safeId)),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'url': uri.toString(),
        'label': label.trim(),
      }),
    ).timeout(const Duration(seconds: 20));
    _decode(result);
  }

  /// Completa una lista registrada hasta el límite de 100 fuentes sin borrar
  /// las listas que ya existan. El servidor elimina duplicados por URL.
  Future<Map<String, dynamic>> addPlaylistSourcesToCatalog({
    required List<Map<String, String>> sources,
  }) async {
    final result = await _client.post(
      Uri.parse(_baseUrl + '/api/channels/admin/sources/bulk'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'sources': sources,
      }),
    ).timeout(const Duration(seconds: 30));
    return _decode(result);
  }

  /// Pone en cola la actualización de las listas registradas.
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

  /// Elimina un canal del catálogo y bloquea su URL para que una importación
  /// posterior no lo vuelva a crear.
  Future<void> deleteChannel(String channelId) async {
    final safeId = channelId.trim();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(safeId)) {
      throw const ChannelCatalogException('El identificador del canal no es válido.');
    }
    final result = await _client.delete(
      Uri.parse(_baseUrl + '/api/channels/admin/channels/' +
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
    final result = await _authenticatedRequest((headers) => _client.patch(
      Uri.parse(_baseUrl + '/api/channels/admin/channels/' +
          encodedId + '/visibility'),
      headers: <String, String>{
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, bool>{'visible': visible}),
    ).timeout(const Duration(seconds: 20)));
    _decode(result);
  }

  Future<void> setChannelSportsClassification(
    String channelId, {
    required bool isSports,
  }) async {
    final safeId = channelId.trim();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(safeId)) {
      throw const ChannelCatalogException('El identificador del canal no es válido.');
    }
    final result = await _client.patch(
      Uri.parse(_baseUrl + '/api/channels/admin/channels/' +
          Uri.encodeComponent(safeId) + '/classification'),
      headers: <String, String>{
        ..._authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, bool>{'isSports': isSports}),
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
      headers: await userAuthorizationHeaders(),
    ).timeout(const Duration(seconds: 20));
    final rows = _decode(result)['channelIds'];
    if (rows is! List) return <String>{};
    return rows.map((id) => id.toString()).toSet();
  }

  Future<void> saveFavorites(Set<String> channelIds) async {
    final result = await _client.put(
      Uri.parse(_baseUrl + '/api/channels/favorites'),
      headers: <String, String>{
        ...await userAuthorizationHeaders(),
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
