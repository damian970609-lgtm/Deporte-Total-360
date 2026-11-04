import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sports_api_service.dart';
import 'automatic_live_service.dart';

/// Cliente seguro del adaptador SportsAPI.app publicado en Cloudflare.
/// La clave del proveedor nunca se incluye en la APK.
class SportsApiAppService {
  SportsApiAppService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  Uri _uri(String route, [Map<String, String> query = const <String, String>{}]) {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor deportivo no es válida.');
    }
    return Uri.parse('$base/api/sportsapi$route').replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<dynamic> _get(
    String route, [
    Map<String, String> query = const <String, String>{},
  ]) {
    return _getResponse(route, query, includeMeta: false);
  }

  Future<dynamic> _getEnvelope(
    String route, [
    Map<String, String> query = const <String, String>{},
  ]) {
    return _getResponse(route, query, includeMeta: true);
  }

  Future<dynamic> _getResponse(
    String route,
    Map<String, String> query, {
    required bool includeMeta,
  }) async {
    try {
      final response = await _client.get(
        _uri(route, query),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        final statusCode = response.statusCode;
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        var message = 'El servidor SportsAPI respondió HTTP ' + statusCode.toString() + '.';
        String? providerCode;
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] != null) {
            final value = error['error'];
            if (value is Map) {
              providerCode = value['code']?.toString();
              final providerMessage = value['message']?.toString();
              if (providerMessage != null && providerMessage.isNotEmpty) {
                message = providerMessage;
              }
            } else {
              message = value.toString();
            }
          }
        } catch (_) {
          // Conserva el código HTTP si el servidor no devuelve JSON.
        }

        if (providerCode == 'rate_limited' || statusCode == 429) {
          final wait = retryAfter ?? 60;
          message = 'SportsAPI recibió demasiadas consultas. Espera ' +
              wait.toString() + ' segundos y vuelve a actualizar.';
        } else if (providerCode == 'quota_exceeded') {
          final wait = retryAfter;
          message = 'Se agotó la cuota de consultas de SportsAPI. ' +
              (wait == null
                  ? 'Vuelve a intentarlo cuando se restablezca el límite del proveedor.'
                  : 'El proveedor indica que se restablece en ' + wait.toString() + ' segundos.');
        } else if (providerCode == 'history_not_in_plan') {
          message = 'La fecha solicitada está fuera del historial incluido en tu plan de SportsAPI.';
        } else if (providerCode == 'endpoint_not_in_plan') {
          message = 'Tu plan de SportsAPI no incluye este tipo de estadísticas.';
        } else if (statusCode == 401) {
          message = 'SportsAPI rechazó la clave configurada en el servidor. Hay que revisar el secreto del Worker.';
        } else if (statusCode == 403) {
          message = 'SportsAPI denegó esta consulta por permisos o por el plan contratado.';
        }

        throw SportsApiException(
          message,
          statusCode: statusCode,
          code: providerCode,
          retryAfterSeconds: retryAfter,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SportsApiException('La respuesta de SportsAPI no tiene el formato esperado.');
      }
      if (route == '/favorites' || includeMeta) return decoded;
      if (!decoded.containsKey('data')) {
        throw const SportsApiException('La respuesta de SportsAPI no contiene el campo data.');
      }
      return decoded['data'];
    } on TimeoutException {
      throw const SportsApiException('La consulta de SportsAPI tardó demasiado.');
    } on SportsApiException {
      rethrow;
    } catch (_) {
      throw const SportsApiException('No se pudo conectar con SportsAPI. Comprueba el Worker y su secreto.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFavoriteSports() async {
    final response = await _get('/favorites');
    if (response is! Map) return <Map<String, dynamic>>[];
    final sports = response['sports'];
    if (sports is! List) return <Map<String, dynamic>>[];
    return sports.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static const Map<String, String> _sportNames = <String, String>{
    'football': 'Fútbol',
    'basketball': 'Baloncesto',
    'baseball': 'Béisbol',
    'ice-hockey': 'Hockey sobre hielo',
    'volleyball': 'Voleibol',
    'mma': 'MMA',
    'futsal': 'Fútbol sala',
    'cycling': 'Ciclismo',
    'motorsport': 'Deportes de motor',
    'handball': 'Balonmano',
  };

  String _text(dynamic value) => value == null ? '' : value.toString().trim();

  String _image(dynamic value) {
    final raw = _text(value);
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? raw
        : '';
  }

  String _score(dynamic value) {
    if (value is Map) return _text(value['current']);
    return _text(value);
  }

  static final Map<String, List<SportsAgendaEvent>> _agendaCache =
      <String, List<SportsAgendaEvent>>{};
  static final Map<String, DateTime> _agendaCacheExpiry =
      <String, DateTime>{};
  static final Map<String, Future<List<SportsAgendaEvent>>> _agendaInFlight =
      <String, Future<List<SportsAgendaEvent>>>{};
  static final Set<String> _agendaSecondDayScheduled = <String>{};

  String _dayKey(DateTime value) =>
      value.year.toString().padLeft(4, '0') + '-' +
      value.month.toString().padLeft(2, '0') + '-' +
      value.day.toString().padLeft(2, '0');

  Future<List<SportsAgendaEvent>> fetchFavoriteAgendaEvents({
    DateTime? date,
    bool forceRefresh = false,
  }) {
    final selected = date ?? DateTime.now();
    final localDay = DateTime(selected.year, selected.month, selected.day);
    final day = _dayKey(localDay);
    final pending = _agendaInFlight[day];
    if (pending != null) return pending;

    final cached = _agendaCache[day];
    final expires = _agendaCacheExpiry[day];
    if (!forceRefresh && cached != null && expires != null &&
        DateTime.now().isBefore(expires)) {
      return Future<List<SportsAgendaEvent>>.value(cached);
    }

    // Mientras se completa la segunda fecha UTC no se vuelve a disparar el
    // bloque de diez consultas de la primera fecha, aunque se pulse Actualizar.
    if (_agendaSecondDayScheduled.contains(day) && cached != null) {
      return Future<List<SportsAgendaEvent>>.value(cached);
    }

    final future = _fetchFavoriteAgendaEvents(localDay);
    _agendaInFlight[day] = future;
    return future.then((events) {
      _agendaCache[day] = events;
      _agendaCacheExpiry[day] = DateTime.now().add(const Duration(minutes: 5));
      return events;
    }).whenComplete(() {
      if (identical(_agendaInFlight[day], future)) {
        _agendaInFlight.remove(day);
      }
    });
  }

  String _competitionKey(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<List<SportsAgendaEvent>> _fetchFavoriteAgendaEvents(
    DateTime localDay,
  ) async {
    // La API recibe una fecha UTC. Una jornada local puede cruzar dos fechas;
    // para no disparar veinte peticiones de golpe, se consulta primero la fecha
    // UTC principal y la segunda se completa tras el reinicio del límite/minuto.
    final localStart = DateTime(localDay.year, localDay.month, localDay.day);
    final localEnd = DateTime(localDay.year, localDay.month, localDay.day + 1);
    final utcStart = localStart.toUtc();
    final utcLastInstant = localEnd.toUtc().subtract(
      const Duration(microseconds: 1),
    );
    final firstUtcDay = DateTime.utc(utcStart.year, utcStart.month, utcStart.day);
    final lastUtcDay = DateTime.utc(
      utcLastInstant.year,
      utcLastInstant.month,
      utcLastInstant.day,
    );
    final utcDays = <String>[];
    for (var day = firstUtcDay;
        !day.isAfter(lastUtcDay);
        day = day.add(const Duration(days: 1))) {
      utcDays.add(_dayKey(day));
    }

    final favoriteSports = await fetchFavoriteSports();
    final favoritesById = <String, Map<String, String>>{};
    for (final sport in favoriteSports) {
      final id = _text(sport['id']);
      final rawCompetitions = sport['competitions'];
      if (id.isEmpty || rawCompetitions is! List) continue;
      final allowed = <String, String>{};
      for (final rawName in rawCompetitions) {
        final name = _text(rawName);
        if (name.isNotEmpty) allowed[_competitionKey(name)] = name;
      }
      favoritesById[id] = allowed;
    }
    if (!_sportNames.keys.every(favoritesById.containsKey) ||
        favoritesById.values.any((items) => items.isEmpty)) {
      throw const SportsApiException(
        'El catálogo de competiciones favoritas está incompleto en el Worker.',
      );
    }

    final firstDayEvents = await _fetchFavoriteAgendaUtcDay(
      utcDays.first,
      localStart,
      localEnd,
      favoritesById,
    );

    if (utcDays.length > 1) {
      final localKey = _dayKey(localDay);
      if (_agendaSecondDayScheduled.add(localKey)) {
        unawaited(_loadSecondUtcDayInBackground(
          localKey,
          utcDays[1],
          localStart,
          localEnd,
          favoritesById,
        ));
      }
    }
    return firstDayEvents;
  }

  Future<void> _loadSecondUtcDayInBackground(
    String localKey,
    String utcDay,
    DateTime localStart,
    DateTime localEnd,
    Map<String, Map<String, String>> favoritesById,
  ) async {
    try {
      // El plan Free admite diez peticiones por minuto. Esperamos más de un
      // minuto antes de completar la fecha UTC nocturna de la jornada local.
      await Future<void>.delayed(const Duration(seconds: 65));
      final additional = await _fetchFavoriteAgendaUtcDay(
        utcDay,
        localStart,
        localEnd,
        favoritesById,
      );
      final mergedById = <String, SportsAgendaEvent>{
        for (final event in (_agendaCache[localKey] ?? <SportsAgendaEvent>[]))
          event.id: event,
        for (final event in additional) event.id: event,
      };
      final merged = mergedById.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      _agendaCache[localKey] = merged;
      _agendaCacheExpiry[localKey] =
          DateTime.now().add(const Duration(minutes: 5));
      await SportsAgendaStore.save(merged);
    } catch (_) {
      // La primera fecha ya se muestra; una segunda fecha fallida no la borra.
    } finally {
      _agendaSecondDayScheduled.remove(localKey);
    }
  }

  Future<List<SportsAgendaEvent>> _fetchFavoriteAgendaUtcDay(
    String utcDay,
    DateTime localStart,
    DateTime localEnd,
    Map<String, Map<String, String>> favoritesById,
  ) async {
    var successfulSports = 0;
    final failures = <String, String>{};

    final results = await Future.wait(_sportNames.entries.map((entry) async {
      final allowed = favoritesById[entry.key] ?? <String, String>{};
      final isRace = entry.key == 'cycling' || entry.key == 'motorsport';
      try {
        final List<dynamic> payload;
        if (isRace) {
          final raceData = await _get(
            '/races',
            <String, String>{'date': utcDay, 'sport': entry.key},
          );
          if (raceData is! List) {
            throw const FormatException(
              'SportsAPI devolvió una agenda de carreras con formato inválido.',
            );
          }
          payload = raceData;
        } else {
          // Una página por deporte evita que la APK agote el límite/minuto
          // recorriendo hasta cien páginas en diez deportes simultáneamente.
          final envelope = await _getEnvelope(
            '/fixtures',
            <String, String>{
              'date': utcDay,
              'sport': entry.key,
              'page': '0',
            },
          );
          if (envelope is! Map || envelope['data'] is! List) {
            throw const FormatException(
              'SportsAPI devolvió una página de agenda con formato inválido.',
            );
          }
          payload = List<dynamic>.from(envelope['data'] as List);
        }
        successfulSports++;

        return payload.whereType<Map>().map((raw) {
          final row = Map<String, dynamic>.from(raw);
          SportsAgendaEvent? event;
          if (isRace) {
            final series = row['series'] is Map
                ? Map<String, dynamic>.from(row['series'])
                : <String, dynamic>{};
            final providerName = entry.key == 'cycling'
                ? _text(row['name'])
                : _text(series['name']);
            final canonical = allowed[_competitionKey(providerName)];
            if (canonical == null) return null;
            if (entry.key == 'motorsport' && series.isNotEmpty) {
              row['series'] = <String, dynamic>{...series, 'name': canonical};
            }
            event = _raceEvent(
              row,
              entry.key,
              entry.value,
              competitionName: canonical,
            );
          } else {
            final league = row['league'] is Map
                ? Map<String, dynamic>.from(row['league'])
                : <String, dynamic>{};
            final canonical = allowed[_competitionKey(_text(league['name']))];
            if (canonical == null) return null;
            row['league'] = <String, dynamic>{...league, 'name': canonical};
            event = _fixtureEvent(row, entry.value);
          }

          if (event == null) return null;
          if (event.startsAt.isBefore(localStart) ||
              !event.startsAt.isBefore(localEnd)) {
            return null;
          }
          return event;
        }).whereType<SportsAgendaEvent>().toList(growable: false);
      } catch (error) {
        failures[entry.key] = error.toString();
        return <SportsAgendaEvent>[];
      }
    }));

    if (successfulSports == 0) {
      final details = failures.entries
          .map((entry) => (_sportNames[entry.key] ?? entry.key) +
              ': ' + entry.value)
          .join(' | ');
      throw SportsApiException(
        details.isEmpty
            ? 'No se pudo consultar ninguno de tus diez deportes favoritos en SportsAPI.'
            : 'SportsAPI no respondió para tus deportes favoritos. ' + details,
      );
    }

    final unique = <String, SportsAgendaEvent>{};
    for (final event in results.expand((items) => items)) {
      unique[event.id] = event;
    }
    return unique.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  SportsAgendaEvent? _fixtureEvent(
    Map<String, dynamic> row,
    String sportName,
  ) {
    final id = int.tryParse(_text(row['id']));
    final start = DateTime.tryParse(_text(row['startTime']));
    if (id == null || start == null) return null;
    final home = row['home'] is Map
        ? Map<String, dynamic>.from(row['home'])
        : <String, dynamic>{};
    final away = row['away'] is Map
        ? Map<String, dynamic>.from(row['away'])
        : <String, dynamic>{};
    final league = row['league'] is Map
        ? Map<String, dynamic>.from(row['league'])
        : <String, dynamic>{};
    final season = row['season'] is Map
        ? Map<String, dynamic>.from(row['season'])
        : <String, dynamic>{};
    final status = row['status'] is Map
        ? Map<String, dynamic>.from(row['status'])
        : <String, dynamic>{};
    final statusType = _text(status['type']).toLowerCase();
    final homeName = _text(home['name']);
    final awayName = _text(away['name']);
    final title = homeName.isNotEmpty && awayName.isNotEmpty
        ? '$homeName vs $awayName'
        : _text(row['name']).isNotEmpty
            ? _text(row['name'])
            : 'Evento de $sportName';
    return SportsAgendaEvent(
      id: 'sportsapi-fixture-$id',
      title: title,
      sport: sportName,
      competition: _text(league['name']),
      homeTeam: homeName,
      awayTeam: awayName,
      homeTeamLogo: _image(home['image']),
      awayTeamLogo: _image(away['image']),
      participants: <SportsAgendaParticipant>[
        if (homeName.isNotEmpty) SportsAgendaParticipant(name: homeName, imageUrl: _image(home['image'])),
        if (awayName.isNotEmpty) SportsAgendaParticipant(name: awayName, imageUrl: _image(away['image'])),
      ],
      status: statusType.isEmpty ? 'scheduled' : statusType,
      statusLabel: _text(status['description']),
      homeScore: _score(row['homeScore']),
      awayScore: _score(row['awayScore']),
      providerLeagueId: int.tryParse(_text(league['id'])),
      providerSeasonId: int.tryParse(_text(season['id'])),
      startsAt: start,
      venue: _text((row['venue'] is Map) ? row['venue']['name'] : row['venue']),
      detailUrl: 'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/fixtures/$id',
    );
  }

  SportsAgendaEvent? _raceEvent(
    Map<String, dynamic> row,
    String sportId,
    String sportName, {
    String? competitionName,
  }) {
    final id = int.tryParse(_text(row['id']));
    if (id == null) return null;
    final sessions = row['sessions'] is List
        ? (row['sessions'] as List).whereType<Map>().toList()
        : <Map>[];
    DateTime? start;
    int sessionId = 0;
    for (final value in sessions) {
      final session = Map<String, dynamic>.from(value);
      final candidate = DateTime.tryParse(_text(session['startTime']));
      if (candidate != null && (start == null || candidate.isBefore(start))) {
        start = candidate;
        sessionId = int.tryParse(_text(session['id'])) ?? 0;
      }
    }
    start ??= DateTime.tryParse(_text(row['startDate']));
    if (start == null) return null;
    final series = row['series'] is Map
        ? Map<String, dynamic>.from(row['series'])
        : <String, dynamic>{};
    final season = row['season'] is Map
        ? Map<String, dynamic>.from(row['season'])
        : <String, dynamic>{};
    final winner = row['winner'] is Map
        ? Map<String, dynamic>.from(row['winner'])
        : <String, dynamic>{};
    final winnerName = _text(winner['name']);
    return SportsAgendaEvent(
      id: 'sportsapi-race-$id-$sessionId',
      title: _text(row['name']).isEmpty ? sportName : _text(row['name']),
      sport: sportName,
      competition: competitionName ?? _text(series['name']),
      participants: winnerName.isEmpty
          ? const <SportsAgendaParticipant>[]
          : <SportsAgendaParticipant>[SportsAgendaParticipant(name: winnerName, imageUrl: _image(winner['image']))],
      homeTeam: winnerName,
      homeTeamLogo: _image(winner['image']),
      status: _text(row['status'] is Map ? row['status']['type'] : row['status']).isEmpty
          ? 'scheduled'
          : _text(row['status'] is Map ? row['status']['type'] : row['status']),
      providerSeriesId: int.tryParse(_text(series['id'])),
      providerSeasonId: int.tryParse(_text(season['id'])),
      startsAt: start,
      detailUrl: 'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/$id',
    );
  }

  Future<dynamic> fetchFixtureStatistics(int fixtureId) {
    return _get('/fixtures/$fixtureId/statistics');
  }

  Future<dynamic> fetchRaceResults(int raceId, {int? sessionId}) {
    return _get('/races/$raceId/results', <String, String>{
      if (sessionId != null && sessionId > 0) 'session': sessionId.toString(),
    });
  }

  Future<dynamic> fetchLeagueStandings({
    required int leagueId,
    required int seasonId,
  }) {
    return _get('/leagues/$leagueId/standings', <String, String>{
      'season': seasonId.toString(),
    });
  }

  Future<dynamic> fetchSeriesStandings({
    required int seriesId,
    required int seasonId,
  }) {
    return _get('/series/$seriesId/standings', <String, String>{
      'season': seasonId.toString(),
      'type': 'competitors',
    });
  }
}
