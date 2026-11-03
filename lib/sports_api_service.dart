import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// URL pública del servidor. La clave APISPORTS_KEY nunca va dentro de la APK.
const String defaultSportsApiBaseUrl =
    'https://deporte-total-360-api.damian970609.workers.dev';

final ValueNotifier<String> sportsApiBaseUrl =
    ValueNotifier<String>(defaultSportsApiBaseUrl);

class SportsApiService {
  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _cacheDuration = Duration(minutes: 3);

  // Reduce las solicitudes repetidas desde este dispositivo.
  // El límite final también depende del uso de otros dispositivos.
  static const Duration _defaultMinimumRequestInterval = Duration(seconds: 10);

  @visibleForTesting
  static Duration minimumRequestIntervalForTesting =
      _defaultMinimumRequestInterval;

  static final http.Client _defaultHttpClient = http.Client();
  @visibleForTesting
  static http.Client? clientOverride;
  static http.Client get _httpClient => clientOverride ?? _defaultHttpClient;

  @visibleForTesting
  static void resetForTesting() {
    _cache.clear();
    _inFlight.clear();
    _lastRequestAt = null;
    minimumRequestIntervalForTesting = _defaultMinimumRequestInterval;
    _requestQueue = Future<void>.value();
  }

  static final Map<String, _CachedRows> _cache =
      <String, _CachedRows>{};

  static final Map<String, Future<List<Map<String, dynamic>>>> _inFlight =
      <String, Future<List<Map<String, dynamic>>>>{};

  static Future<void> _requestQueue = Future<void>.value();
  static DateTime? _lastRequestAt;

  static String? normalizeBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path)
        .toString()
        .replaceAll(RegExp(r'/+$'), '');
  }

  static String _dateParam(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }



  /// Comprueba el endpoint real de partidos después de validar el Worker.
  /// Una respuesta 204 o una lista vacía significa que no hay eventos en el
  /// rango, no que la conexión esté rota.
  Future<int> checkFootballFixtures([String? baseUrl]) async {
    final base = normalizeBaseUrl(baseUrl ?? sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor no es válida.');
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 6));
    final uri = Uri.parse('$base/api/fixtures').replace(
      queryParameters: <String, String>{
        'from': _dateParam(start),
        'to': _dateParam(end),
        'timezone': 'America/Guyana',
      },
    );
    try {
      final response = await _httpClient.get(uri).timeout(_timeout);
      if (response.statusCode == 204) return 0;
      if (response.statusCode != 200) {
        var detail = '';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final message = decoded['error'] ?? decoded['message'];
            final details = decoded['details'] ?? decoded['errors'];
            if (message != null) detail = message.toString();
            if (details != null) {
              detail = detail.isEmpty ? details.toString() : detail + ': ' + details.toString();
            }
          }
        } catch (_) {
          // Se conserva el código HTTP aunque el servidor no envíe JSON.
        }
        if (detail.length > 240) detail = detail.substring(0, 237) + '…';
        throw SportsApiException(
          'La consulta de partidos respondió HTTP ' +
          response.statusCode.toString() +
          (detail.isEmpty ? '.' : ': ' + detail),
        );
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const SportsApiException(
          'La consulta de partidos devolvió JSON inválido.',
        );
      }
      if (decoded is! Map) {
        throw const SportsApiException(
          'La respuesta de partidos no tiene el formato esperado.',
        );
      }
      final errors = decoded['errors'];
      final hasErrors = errors is List
          ? errors.isNotEmpty
          : errors is Map
              ? errors.isNotEmpty
              : errors != null && errors != false && errors.toString().trim().isNotEmpty;
      if (hasErrors) {
        throw SportsApiException('API-Sports devolvió errores: ' + errors.toString());
      }
      final rows = decoded['response'];
      if (rows is! List) {
        throw const SportsApiException(
          'La respuesta del proveedor no contiene una lista de partidos.',
        );
      }
      return rows.length;
    } on TimeoutException {
      throw const SportsApiException(
        'El servidor tardó demasiado al consultar los partidos.',
      );
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException(
        'No se pudo consultar el endpoint real de partidos. Comprueba Internet y el Worker.',
      );
    }
  }

  Future<void> checkHealth([String? baseUrl]) async {
    final base = normalizeBaseUrl(
      baseUrl ?? sportsApiBaseUrl.value,
    );

    if (base == null) {
      throw const SportsApiException(
        'La URL del servidor no es válida.',
      );
    }

    try {
      final response = await _httpClient
          .get(Uri.parse('$base/health'))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw SportsApiException(
          'El servidor respondió HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SportsApiException(
          'El Worker respondió, pero el estado no tiene el formato esperado.',
        );
      }

      final status = decoded['status']?.toString().toLowerCase();
      if (status != 'online') {
        throw SportsApiException(
          'El Worker no confirmó que esté operativo (estado: ${status ?? 'desconocido'}).',
        );
      }
      if (decoded['provider_configured'] != true) {
        throw const SportsApiException(
          'El Worker está disponible, pero no tiene configurada la clave APISPORTS_KEY.',
        );
      }
    } on TimeoutException {
      throw const SportsApiException(
        'El servidor tardó demasiado en responder.',
      );
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException(
        'No se pudo verificar la conexión con el Worker.',
      );
    }
  }

  /// Compatibilidad con las llamadas antiguas de fútbol.
  Future<List<Map<String, dynamic>>> fetchFixtures() {
    return fetchAgendaEvents(
      sport: 'Fútbol',
      dateFilter: 'Todos',
    );
  }

  /// Lee el catálogo de señales autorizado del Worker.
  /// Es independiente de API-Sports y no rastrea ni extrae páginas web.
  Future<List<Map<String, dynamic>>> fetchAuthorizedLiveSources({
    String? sport,
    required String dateFilter,
  }) async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    final sportId = sport == null || sport == 'Todos'
        ? null
        : supportedSports[sport];
    if (base == null || (sport != null && sport != 'Todos' && sportId == null)) {
      return <Map<String, dynamic>>[];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = dateFilter == 'Mañana'
        ? today.add(const Duration(days: 1))
        : today;
    final end = dateFilter == 'Todos'
        ? today.add(const Duration(days: 6))
        : start;
    final query = <String, String>{
      'from': _dateParam(start),
      'to': _dateParam(end),
      'timezone': 'America/Guyana',
    };
    if (sportId != null) query['sport'] = sportId;
    final uri = Uri.parse('$base/api/live/sources').replace(
      queryParameters: query,
    );

    try {
      final response = await _httpClient
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      // Compatibilidad con un Worker anterior que aún no tenga esta ruta.
      if (response.statusCode == 404 || response.statusCode == 204) {
        return <Map<String, dynamic>>[];
      }
      if (response.statusCode != 200) {
        throw SportsApiException(
          'El catálogo de señales respondió HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return <Map<String, dynamic>>[];
      final payload = decoded['sources'] ?? decoded['response'] ?? decoded['data'];
      if (payload is! List) return <Map<String, dynamic>>[];
      return payload
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } on TimeoutException {
      throw const SportsApiException('El catálogo de señales tardó demasiado en responder.');
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException('No se pudo consultar el catálogo de señales.');
    }
  }

  /// Consulta el deporte y la fecha seleccionados en la agenda.
  Future<List<Map<String, dynamic>>> fetchAgendaEvents({
    required String sport,
    required String dateFilter,
  }) async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);

    if (base == null) {
      throw const SportsApiException(
        'Configura una URL HTTPS válida del servidor.',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = dateFilter == 'Mañana'
        ? today.add(const Duration(days: 1))
        : today;

    late final String route;
    var includeTimezone = true;

    switch (sport) {
      case 'Fútbol':
        route = '/api/fixtures';
        break;

      case 'Básquet':
        route = '/api/basketball/games';
        break;

      case 'NBA':
        route = '/api/nba/games';
        includeTimezone = false;
        break;

      case 'Béisbol':
        route = '/api/baseball/games';
        break;

      case 'Fútbol americano':
        route = '/api/american-football/games';
        break;

      case 'Hockey sobre hielo':
        route = '/api/hockey/games';
        break;

      case 'Balonmano':
        route = '/api/handball/games';
        break;

      case 'Rugby':
        route = '/api/rugby/games';
        break;

      case 'Vóley':
        route = '/api/volleyball/games';
        break;

      case 'Fútbol australiano':
        route = '/api/afl/games';
        break;

      case 'Fórmula 1':
        route = '/api/formula-1/races';
        includeTimezone = false;
        break;

      case 'MMA':
        route = '/api/mma/fights';
        break;

      case 'Tenis':
      case 'Otros':
        throw SportsApiException(
          '$sport no tiene una ruta de partidos en el Worker actual.',
        );

      default:
        throw SportsApiException(
          'No existe una ruta de partidos para $sport.',
        );
    }

    // El Worker de fútbol admite rangos from/to.
    // Los otros calendarios requieren una fecha concreta.
    // Los calendarios no futbolísticos consultan una fecha concreta; cuando
    // se elige Todos se usa hoy sin fallar la carga del deporte.

    final query = <String, String>{};

    if (sport == 'Fórmula 1') {
      query['season'] = today.year.toString();
    } else if (sport == 'Fútbol' && dateFilter == 'Todos') {
      query['from'] = _dateParam(today);
      query['to'] = _dateParam(
        today.add(const Duration(days: 6)),
      );
    } else {
      query['date'] = _dateParam(selectedDate);
    }

    if (includeTimezone) {
      query['timezone'] = 'America/Guyana';
    }

    final uri = Uri.parse('$base$route').replace(
      queryParameters: query,
    );

    return _getRows(uri);
  }

  static const Map<String, String> supportedSports = <String, String>{
    'Fútbol': 'football',
    'Básquet': 'basketball',
    'NBA': 'nba',
    'Béisbol': 'baseball',
    'Fútbol americano': 'american-football',
    'Hockey sobre hielo': 'hockey',
    'Balonmano': 'handball',
    'Rugby': 'rugby',
    'Vóley': 'volleyball',
    'Fútbol australiano': 'afl',
    'Fórmula 1': 'formula-1',
    'MMA': 'mma',
  };

  String _resourceRoute(String sport, String resource) {
    final sportId = supportedSports[sport];
    if (sportId == null) {
      throw SportsApiException(sport + ' no tiene un recurso de ' + resource + ' disponible.');
    }
    return '/api/' + sportId + '/' + resource;
  }

  Future<List<Map<String, dynamic>>> fetchLeagues({
    required String sport,
    required String search,
  }) async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) throw const SportsApiException('Configura una URL HTTPS válida del servidor.');
    final term = search.trim();
    if (term.isEmpty) throw const SportsApiException('Escribe el nombre de una liga o competición.');
    final route = _resourceRoute(sport, 'leagues');
    // La API de NBA usa "name"; los demás catálogos usan "search".
    final queryKey = sport == 'NBA' ? 'name' : 'search';
    final uri = Uri.parse('$base$route').replace(
      queryParameters: <String, String>{queryKey: term},
    );
    return _getRows(uri);
  }

  Future<List<Map<String, dynamic>>> fetchStandings({
    required String sport,
    required String leagueId,
    required String season,
  }) async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) throw const SportsApiException('Configura una URL HTTPS válida del servidor.');
    final id = leagueId.trim();
    final year = season.trim();
    if (!RegExp(r'^\d+$').hasMatch(id) || int.tryParse(id) == null || int.parse(id) < 1) {
      throw const SportsApiException('El identificador de liga debe ser numérico.');
    }
    if (!RegExp(r'^\d{4}(?:-\d{4})?$').hasMatch(year)) {
      throw const SportsApiException('La temporada debe tener formato 2026 o 2025-2026.');
    }
    final route = _resourceRoute(sport, 'standings');
    final uri = Uri.parse('$base$route').replace(queryParameters: <String, String>{'league': id, 'season': year});
    return _getRows(uri);
  }


  /// Clasificaciones específicas de Fórmula 1: pilotos o constructores.
  Future<List<Map<String, dynamic>>> fetchFormula1Rankings({
    required String season,
    required String ranking,
  }) async {
    final year = season.trim();
    if (year.length != 4 || int.tryParse(year) == null) {
      throw const SportsApiException('La temporada debe tener formato YYYY.');
    }
    if (ranking != 'driver-rankings' && ranking != 'team-rankings') {
      throw const SportsApiException('Clasificación de Fórmula 1 no válida.');
    }
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) throw const SportsApiException('Configura una URL HTTPS válida del servidor.');
    final uri = Uri.parse(base + '/api/formula-1/' + ranking).replace(
      queryParameters: <String, String>{'season': year},
    );
    return _getRows(uri);
  }

  /// Calendario de combates de MMA para una fecha concreta.
  Future<List<Map<String, dynamic>>> fetchMmaFights({DateTime? date}) async {
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) throw const SportsApiException('Configura una URL HTTPS válida del servidor.');
    final selectedDate = date ?? DateTime.now();
    final day = selectedDate.year.toString().padLeft(4, '0') + '-' +
        selectedDate.month.toString().padLeft(2, '0') + '-' +
        selectedDate.day.toString().padLeft(2, '0');
    final uri = Uri.parse(base + '/api/mma/fights').replace(
      queryParameters: <String, String>{'date': day},
    );
    return _getRows(uri);
  }

  /// Busca luchadores por nombre sin exponer la clave del proveedor.
  Future<List<Map<String, dynamic>>> fetchMmaFighters({required String search}) async {
    final term = search.trim();
    if (term.isEmpty) throw const SportsApiException('Escribe el nombre de un luchador.');
    final base = normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) throw const SportsApiException('Configura una URL HTTPS válida del servidor.');
    final uri = Uri.parse(base + '/api/mma/fighters').replace(
      queryParameters: <String, String>{'search': term},
    );
    return _getRows(uri);
  }


  /// Carga los deportes por separado; un proveedor sin cobertura no impide
  /// mostrar los eventos devueltos por las demás disciplinas.
  Future<List<Map<String, dynamic>>> fetchAllAgendaEvents({
    required String dateFilter,
    void Function(String sport, Object error)? onSportError,
    void Function(String sport, List<Map<String, dynamic>> rows)? onSportComplete,
  }) async {
    final sports = supportedSports.keys.toList(growable: false);
    final results = await Future.wait(sports.map((sport) async {
      try {
        final rows = await fetchAgendaEvents(
          sport: sport,
          dateFilter: dateFilter,
        );
        final taggedRows = rows.map((row) => <String, dynamic>{
          ...row,
          '_sportName': sport,
        }).toList(growable: false);
        onSportComplete?.call(sport, taggedRows);
        return taggedRows;
      } catch (error) {
        onSportError?.call(sport, error);
        onSportComplete?.call(sport, const <Map<String, dynamic>>[]);
        return <Map<String, dynamic>>[];
      }
    }));
    return results.expand((rows) => rows).toList(growable: false);
  }

  static Future<void> _reserveRequestSlot() async {
    final previous = _requestQueue;
    final release = Completer<void>();

    _requestQueue = release.future;

    await previous;

    try {
      final last = _lastRequestAt;

      if (last != null) {
        final elapsed = DateTime.now().difference(last);

        if (elapsed < minimumRequestIntervalForTesting) {
          await Future<void>.delayed(
            minimumRequestIntervalForTesting - elapsed,
          );
        }
      }

      _lastRequestAt = DateTime.now();
    } finally {
      release.complete();
    }
  }

  Future<List<Map<String, dynamic>>> _getRows(Uri uri) async {
    final key = uri.toString();

    final cached = _cache[key];

    if (cached != null) {
      if (DateTime.now().isBefore(cached.expiresAt)) {
        return cached.rows;
      }

      _cache.remove(key);
    }

    final pending = _inFlight[key];

    if (pending != null) {
      return pending;
    }

    final future = _requestRows(uri, key);
    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<Map<String, dynamic>>> _requestRows(
    Uri uri,
    String cacheKey,
  ) async {
    try {
      await _reserveRequestSlot();

      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode == 204) {
        const emptyRows = <Map<String, dynamic>>[];

        _cache[cacheKey] = _CachedRows(
          emptyRows,
          DateTime.now().add(_cacheDuration),
        );

        return emptyRows;
      }

      final bodyLower = response.body.toLowerCase();

      if (response.statusCode == 429 ||
          bodyLower.contains('too many requests') ||
          bodyLower.contains('rate limit') ||
          bodyLower.contains('ratelimit')) {
        throw const SportsApiException(
          'API-Sports alcanzó el límite de consultas. '
          'Espera al menos un minuto antes de volver a intentarlo.',
        );
      }

      if (response.statusCode != 200) {
        var detail = '';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map) {
            final message = errorBody['error'] ??
                errorBody['message'] ??
                errorBody['errors'];
            final providerStatus = errorBody['provider_status'];
            final providerDetails = errorBody['details'];
            if (message != null) detail = message.toString();
            if (providerStatus != null) {
              detail = detail.isEmpty
                  ? 'Proveedor HTTP $providerStatus'
                  : '$detail (proveedor HTTP $providerStatus)';
            }
            if (providerDetails != null) {
              final detailsText = providerDetails.toString();
              detail = detail.isEmpty ? detailsText : '$detail · $detailsText';
            }
          }
        } catch (_) {
          // El mensaje HTTP sigue siendo útil aunque el cuerpo no sea JSON.
        }
        if (detail.length > 280) detail = '${detail.substring(0, 277)}…';
        throw SportsApiException(
          'El servidor de partidos respondió HTTP ${response.statusCode}'
          '${detail.isEmpty ? '.' : ': $detail'}',
        );
      }

      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const SportsApiException(
          'El servidor devolvió una respuesta JSON inválida.',
        );
      }

      if (decoded is! Map) {
        throw const SportsApiException(
          'La respuesta deportiva no tiene el formato esperado.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final errors = data['errors'];

      final hasErrors = errors is List
          ? errors.isNotEmpty
          : errors is Map
              ? errors.isNotEmpty
              : errors != null &&
                  errors != false &&
                  errors.toString().trim().isNotEmpty;

      if (hasErrors) {
        final errorText = errors.toString().toLowerCase();

        if (errorText.contains('too many requests') ||
            errorText.contains('rate limit') ||
            errorText.contains('ratelimit')) {
          throw const SportsApiException(
            'API-Sports alcanzó el límite de consultas. '
            'Espera al menos un minuto antes de volver a intentarlo.',
          );
        }

        throw SportsApiException(
          'El proveedor deportivo devolvió un error: $errors',
        );
      }

      final rawRows = data['response'];

      if (rawRows is! List) {
        throw const SportsApiException(
          'La respuesta no contiene la lista de eventos.',
        );
      }

      final rows = rawRows
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList(growable: false);

      _cache[cacheKey] = _CachedRows(
        rows,
        DateTime.now().add(_cacheDuration),
      );

      return rows;
    } on TimeoutException {
      throw const SportsApiException(
        'La consulta tardó demasiado. Comprueba tu conexión.',
      );
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException(
        'No se pudo conectar con el servidor deportivo.',
      );
    }
  }
}

class _CachedRows {
  const _CachedRows(this.rows, this.expiresAt);

  final List<Map<String, dynamic>> rows;
  final DateTime expiresAt;
}

class SportsApiException implements Exception {
  const SportsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
