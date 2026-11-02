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
  static const Duration _minimumRequestInterval = Duration(seconds: 10);

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
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw SportsApiException(
          'El servidor respondió HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map &&
          decoded['provider_configured'] == false) {
        throw const SportsApiException(
          'El Worker no tiene configurada la clave APISPORTS_KEY.',
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
    if (sport != 'Fútbol' && dateFilter == 'Todos') {
      throw const SportsApiException(
        'Para este deporte selecciona Hoy o Mañana. '
        'La ruta actual no admite un rango de fechas.',
      );
    }

    final query = <String, String>{};

    if (sport == 'Fútbol' && dateFilter == 'Todos') {
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

  static const Map<String, String> _sportRouteIds = <String, String>{
    'Básquet': 'basketball',
    'NBA': 'nba',
    'Béisbol': 'baseball',
    'Fútbol americano': 'american-football',
    'Hockey sobre hielo': 'hockey',
    'Balonmano': 'handball',
    'Rugby': 'rugby',
    'Vóley': 'volleyball',
    'Fútbol australiano': 'afl',
  };

  String _resourceRoute(String sport, String resource) {
    if (sport == 'Fútbol') {
      if (resource == 'leagues') return '/api/leagues';
      if (resource == 'standings') return '/api/standings';
    }
    final sportId = _sportRouteIds[sport];
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

  /// Ordena las solicitudes para evitar ráfagas de consultas.
  static Future<void> _reserveRequestSlot() async {
    final previous = _requestQueue;
    final release = Completer<void>();

    _requestQueue = release.future;

    await previous;

    try {
      final last = _lastRequestAt;

      if (last != null) {
        final elapsed = DateTime.now().difference(last);

        if (elapsed < _minimumRequestInterval) {
          await Future<void>.delayed(
            _minimumRequestInterval - elapsed,
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

      final response = await http.get(uri).timeout(_timeout);

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
        throw SportsApiException(
          'El servidor de partidos respondió HTTP ${response.statusCode}.',
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