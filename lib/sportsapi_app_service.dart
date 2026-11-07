import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sports_api_service.dart';
import 'automatic_live_service.dart';

/// Cliente seguro del adaptador SportsAPI.app publicado en Cloudflare.
/// La clave del proveedor nunca se incluye en la APK.
class SportsAgendaWindow {
  const SportsAgendaWindow({
    required this.startDate,
    required this.days,
    required this.events,
    this.unavailableDates = const <DateTime>[],
  });

  final DateTime startDate;
  final int days;
  final List<SportsAgendaEvent> events;
  final List<DateTime> unavailableDates;
}

class _AgendaDayResult {
  const _AgendaDayResult({
    required this.date,
    required this.events,
    this.failed = false,
    this.incomplete = false,
  });

  final DateTime date;
  final List<SportsAgendaEvent> events;
  final bool failed;
  final bool incomplete;
}

class _AgendaSportsResult {
  const _AgendaSportsResult({
    required this.events,
    this.incomplete = false,
  });

  final List<SportsAgendaEvent> events;
  final bool incomplete;
}

class _AgendaSportResult {
  const _AgendaSportResult({
    required this.events,
    this.failed = false,
  });

  final List<SportsAgendaEvent> events;
  final bool failed;
}

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
    bool includeEnvelope = false,
  ]) async {
    try {
      final response = await _client.get(
        _uri(route, query),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        var detail = '';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] != null) {
            final value = error['error'];
            detail = value is Map
                ? (value['message'] ?? value['code'] ?? '').toString()
                : value.toString();
          }
        } catch (_) {
          // Se conserva el código HTTP aunque el servidor no envíe JSON.
        }
        if (detail.length > 220) detail = '${detail.substring(0, 217)}…';
        final retryAfter = response.headers['retry-after'];
        throw SportsApiException(
          'El servidor SportsAPI respondió HTTP ${response.statusCode}'
          '${detail.isEmpty ? '.' : ': $detail'}'
          '${retryAfter == null ? '' : ' Retry-After: $retryAfter'}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SportsApiException('La respuesta de SportsAPI no tiene el formato esperado.');
      }
      if (route == '/favorites' || includeEnvelope) return decoded;
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

  static final Map<String, _AgendaSportsResult> _agendaCache =
      <String, _AgendaSportsResult>{};
  static final Map<String, DateTime> _agendaCacheExpiry =
      <String, DateTime>{};
  static final Map<String, Future<_AgendaSportsResult>> _agendaInFlight =
      <String, Future<_AgendaSportsResult>>{};
  static final Map<String, ({
    SportsAgendaWindow window,
    DateTime expiresAt,
  })> _agendaWindowCache =
      <String, ({SportsAgendaWindow window, DateTime expiresAt})>{};
  static final Map<String, Future<SportsAgendaWindow>> _agendaWindowInFlight =
      <String, Future<SportsAgendaWindow>>{};


  Future<List<SportsAgendaEvent>> fetchFavoriteAgendaEvents({
    DateTime? date,
  }) async {
    final requested = date ?? DateTime.now().toUtc();
    final result = await _fetchCachedAgendaDay(requested);
    return result.events;
  }

  Future<_AgendaSportsResult> _fetchCachedAgendaDay(DateTime date) {
    final utcDay = DateTime.utc(date.year, date.month, date.day);
    final day = utcDay.year.toString().padLeft(4, '0') + '-' +
        utcDay.month.toString().padLeft(2, '0') + '-' +
        utcDay.day.toString().padLeft(2, '0');
    final cached = _agendaCache[day];
    final expires = _agendaCacheExpiry[day];
    if (cached != null && expires != null && DateTime.now().isBefore(expires)) {
      return Future<_AgendaSportsResult>.value(cached);
    }
    final pending = _agendaInFlight[day];
    if (pending != null) return pending;
    final future = _fetchFavoriteAgendaEvents(day);
    _agendaInFlight[day] = future;
    return future.then((result) {
      _agendaCache[day] = result;
      _agendaCacheExpiry[day] =
          DateTime.now().add(const Duration(hours: 6));
      return result;
    }).whenComplete(() {
      _agendaInFlight.remove(day);
    });
  }

  /// Descarga hoy y los seis días siguientes. Se consultan dos fechas a la
  /// vez para limitar el número de conexiones concurrentes al Worker.
  Future<SportsAgendaWindow> fetchFavoriteAgendaWindow({
    DateTime? startDate,
    int days = 7,
    bool forceRefresh = false,
  }) {
    final requested = (startDate ?? DateTime.now()).toLocal();
    final firstDay = DateTime(requested.year, requested.month, requested.day);
    final safeDays = days.clamp(1, 7).toInt();
    final firstKey = firstDay.year.toString().padLeft(4, '0') + '-' +
        firstDay.month.toString().padLeft(2, '0') + '-' +
        firstDay.day.toString().padLeft(2, '0');
    final cacheKey = firstKey + ':' + safeDays.toString();
    if (forceRefresh) {
      _agendaWindowCache.remove(cacheKey);
      _agendaCache.clear();
      _agendaCacheExpiry.clear();
    }
    final now = DateTime.now();
    final cached = _agendaWindowCache[cacheKey];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future<SportsAgendaWindow>.value(cached.window);
    }
    final pending = _agendaWindowInFlight[cacheKey];
    if (pending != null) return pending;

    final future = _fetchFavoriteAgendaWindow(firstDay, safeDays);
    _agendaWindowInFlight[cacheKey] = future;
    return future.then((window) {
      _agendaWindowCache[cacheKey] = (
        window: window,
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );
      return window;
    }).whenComplete(() {
      _agendaWindowInFlight.remove(cacheKey);
    });
  }

  Future<SportsAgendaWindow> _fetchFavoriteAgendaWindow(
    DateTime startDate,
    int days,
  ) async {
    final localStart = DateTime(startDate.year, startDate.month, startDate.day);
    final localEnd = localStart.add(Duration(days: days));

    // A local seven-day window may overlap eight UTC calendar dates in
    // UTC-negative time zones. SportsAPI accepts UTC dates, so query every
    // UTC date whose interval intersects the requested local window.
    final firstUtcInstant = localStart.toUtc();
    final lastUtcInstant = localEnd.toUtc().subtract(
      const Duration(milliseconds: 1),
    );
    final firstUtcDay = DateTime.utc(
      firstUtcInstant.year,
      firstUtcInstant.month,
      firstUtcInstant.day,
    );
    final lastUtcDay = DateTime.utc(
      lastUtcInstant.year,
      lastUtcInstant.month,
      lastUtcInstant.day,
    );
    final utcDays = lastUtcDay.difference(firstUtcDay).inDays + 1;

    final resultsById = <String, SportsAgendaEvent>{};
    final unavailableLocalDays = <DateTime>{};

    void markUnavailableUtcDay(DateTime utcDay) {
      final utcEnd = utcDay
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1));
      final firstLocal = utcDay.toLocal();
      final lastLocal = utcEnd.toLocal();
      var localDay = DateTime(
        firstLocal.year,
        firstLocal.month,
        firstLocal.day,
      );
      final lastLocalDay = DateTime(
        lastLocal.year,
        lastLocal.month,
        lastLocal.day,
      );
      while (!localDay.isAfter(lastLocalDay)) {
        if (!localDay.isBefore(localStart) && localDay.isBefore(localEnd)) {
          unavailableLocalDays.add(localDay);
        }
        localDay = localDay.add(const Duration(days: 1));
      }
    }

    // Consulta un día UTC cada vez; dentro de cada fecha se limita también
    // la concurrencia por deporte para no saturar el Worker ni el proveedor.
    for (var dayIndex = 0; dayIndex < utcDays; dayIndex++) {
      final date = firstUtcDay.add(Duration(days: dayIndex));
      _AgendaDayResult result;
      try {
        final dayResult = await _fetchCachedAgendaDay(date);
        result = _AgendaDayResult(
          date: date,
          events: dayResult.events,
          incomplete: dayResult.incomplete,
        );
      } catch (_) {
        result = _AgendaDayResult(
          date: date,
          events: const <SportsAgendaEvent>[],
          failed: true,
        );
      }
      if (result.failed) {
        markUnavailableUtcDay(result.date);
        continue;
      }
      if (result.incomplete) markUnavailableUtcDay(result.date);
      for (final event in result.events) {
        resultsById[event.id] = event;
      }
    }

    final events = resultsById.values.where((event) {
      final localEventStart = event.startsAt.toLocal();
      return !localEventStart.isBefore(localStart) &&
          localEventStart.isBefore(localEnd);
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final unavailableDates = unavailableLocalDays.toList()
      ..sort((a, b) => a.compareTo(b));
    return SportsAgendaWindow(
      startDate: localStart,
      days: days,
      events: events,
      unavailableDates: unavailableDates,
    );
  }

  Future<_AgendaSportsResult> _fetchFavoriteAgendaEvents(String day) async {

    Future<Map<String, dynamic>> fetchCompleteEnvelope(
      String route,
      Map<String, String> query,
    ) async {
      Future<Map<String, dynamic>> request() async {
        final raw = await _get(route, query, true);
        if (raw is! Map) {
          throw const FormatException(
            'SportsAPI devolvió una respuesta con formato inválido.',
          );
        }
        return Map<String, dynamic>.from(raw);
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final envelope = await request();
          final meta = envelope['meta'] is Map
              ? Map<String, dynamic>.from(envelope['meta'] as Map)
              : <String, dynamic>{};
          if (meta['complete'] != false) return envelope;
          if (attempt == 2) {
            throw const SportsApiException(
              'SportsAPI devolvió datos incompletos tres veces.',
            );
          }
        } catch (error) {
          final message = error.toString();
          final retryable =
              RegExp(r'HTTP (408|429|5[0-9][0-9])').hasMatch(message) ||
              message.contains('tardó demasiado') ||
              message.contains('No se pudo conectar');
          if (!retryable || attempt == 2) rethrow;

          final retryMatch =
              RegExp(r'Retry-After:\s*(\d+)', caseSensitive: false)
                  .firstMatch(message);
          final retrySeconds = int.tryParse(retryMatch?.group(1) ?? '');
          final wait = retrySeconds == null
              ? Duration(milliseconds: 700 * (attempt + 1))
              : Duration(seconds: retrySeconds.clamp(1, 90).toInt());
          await Future<void>.delayed(wait);
          continue;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
      throw const SportsApiException(
        'SportsAPI no respondió con datos completos después de tres intentos.',
      );
    }

    final entries = _sportNames.entries.toList(growable: false);
    final resultsByIndex = List<_AgendaSportResult?>.filled(entries.length, null);
    var nextIndex = 0;

    Future<void> runSportWorker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= entries.length) return;
        final entry = entries[index];
        try {
          final isRace = entry.key == 'cycling' || entry.key == 'motorsport';
          final rows = <Map<String, dynamic>>[];
          if (isRace) {
            final envelope = await fetchCompleteEnvelope(
              '/races', <String, String>{'date': day, 'sport': entry.key},
            );
            final payload = envelope['data'];
            if (payload is! List) {
              throw const FormatException(
                'SportsAPI devolvió una agenda de carreras con formato inválido.',
              );
            }
            rows.addAll(payload.whereType<Map>().map(
              (raw) => Map<String, dynamic>.from(raw),
            ));
          } else {
            var finishedPages = false;
            for (var page = 0; page < 100; page++) {
              final envelope = await fetchCompleteEnvelope(
                '/fixtures',
                <String, String>{
                  'date': day, 'sport': entry.key, 'page': page.toString(),
                },
              );
              final payload = envelope['data'];
              if (payload is! List) {
                throw const FormatException(
                  'SportsAPI devolvió una agenda de partidos con formato inválido.',
                );
              }
              rows.addAll(payload.whereType<Map>().map(
                (raw) => Map<String, dynamic>.from(raw),
              ));
              final meta = envelope['meta'] is Map
                  ? Map<String, dynamic>.from(envelope['meta'] as Map)
                  : <String, dynamic>{};
              if (meta['hasNextPage'] != true) {
                finishedPages = true;
                break;
              }
            }
            if (!finishedPages) {
              throw const SportsApiException(
                'SportsAPI superó el límite seguro de cien páginas para un deporte.',
              );
            }
          }
          final events = isRace
              ? rows.expand((row) => _raceEvents(row, entry.value, day))
                  .toList(growable: false)
              : rows.map((row) => _fixtureEvent(row, entry.value))
                  .whereType<SportsAgendaEvent>().toList(growable: false);
          resultsByIndex[index] = _AgendaSportResult(events: events);
        } catch (_) {
          resultsByIndex[index] = const _AgendaSportResult(
            events: <SportsAgendaEvent>[], failed: true,
          );
        }
      }
    }

    await Future.wait<void>(List<Future<void>>.generate(
      5, (_) => runSportWorker(), growable: false,
    ));
    final results = resultsByIndex.cast<_AgendaSportResult>();

    final successfulSports = results.where((result) => !result.failed).length;
    if (successfulSports == 0) {
      throw const SportsApiException(
        'No se pudo consultar ninguno de tus diez deportes favoritos en SportsAPI.',
      );
    }
    final unique = <String, SportsAgendaEvent>{};
    for (final event in results.expand((result) => result.events)) {
      unique[event.id] = event;
    }
    final events = unique.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _AgendaSportsResult(
      events: events,
      incomplete: results.any((result) => result.failed),
    );
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

  List<SportsAgendaEvent> _raceEvents(
    Map<String, dynamic> row,
    String sportName,
    String utcDay,
  ) {
    final id = int.tryParse(_text(row['id']));
    if (id == null) return const <SportsAgendaEvent>[];
    final sessions = row['sessions'] is List
        ? (row['sessions'] as List).whereType<Map>().toList()
        : <Map>[];
    final dayEvents = <SportsAgendaEvent>[];

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
    final raceName = _text(row['name']).isEmpty
        ? sportName
        : _text(row['name']);
    final rawStatus = row['status'] is Map
        ? row['status']['type']
        : row['status'];
    final raceStatus = _text(rawStatus).isEmpty
        ? 'scheduled'
        : _text(rawStatus);

    for (final value in sessions) {
      final session = Map<String, dynamic>.from(value);
      final start = DateTime.tryParse(_text(session['startTime']));
      if (start == null) continue;
      final utcStart = start.toUtc();
      final sessionDay = utcStart.year.toString().padLeft(4, '0') + '-' +
          utcStart.month.toString().padLeft(2, '0') + '-' +
          utcStart.day.toString().padLeft(2, '0');
      if (sessionDay != utcDay) continue;

      final sessionId = int.tryParse(_text(session['id'])) ?? 0;
      final sessionType = _text(session['type'] ?? session['name']);
      final sessionStatus = _text(
        session['status'] is Map
            ? session['status']['type']
            : session['status'],
      );
      final title = sessionType.isEmpty
          ? raceName
          : raceName + ' · ' + sessionType.toUpperCase();

      dayEvents.add(SportsAgendaEvent(
        id: 'sportsapi-race-$id-$sessionId',
        title: title,
        sport: sportName,
        competition: _text(series['name']),
        participants: winnerName.isEmpty
            ? const <SportsAgendaParticipant>[]
            : <SportsAgendaParticipant>[
                SportsAgendaParticipant(
                  name: winnerName,
                  imageUrl: _image(winner['image']),
                ),
              ],
        homeTeam: winnerName,
        homeTeamLogo: _image(winner['image']),
        status: sessionStatus.isEmpty ? raceStatus : sessionStatus,
        providerSeriesId: int.tryParse(_text(series['id'])),
        providerSeasonId: int.tryParse(_text(season['id'])),
        startsAt: start,
        detailUrl:
            'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/$id',
      ));
    }

    // Some race records have no sessions. Show a date-only event only on
    // their published start date; do not copy it into every following day.
    if (dayEvents.isEmpty && sessions.isEmpty) {
      final startDate = _text(row['startDate']);
      if (startDate == utcDay) {
        final start = DateTime.tryParse(startDate);
        if (start != null) {
          dayEvents.add(SportsAgendaEvent(
            id: 'sportsapi-race-$id-0',
            title: raceName,
            sport: sportName,
            competition: _text(series['name']),
            participants: winnerName.isEmpty
                ? const <SportsAgendaParticipant>[]
                : <SportsAgendaParticipant>[
                    SportsAgendaParticipant(
                      name: winnerName,
                      imageUrl: _image(winner['image']),
                    ),
                  ],
            homeTeam: winnerName,
            homeTeamLogo: _image(winner['image']),
            status: raceStatus,
            providerSeriesId: int.tryParse(_text(series['id'])),
            providerSeasonId: int.tryParse(_text(season['id'])),
            startsAt: start,
            detailUrl:
                'https://deporte-total-360-api.damian970609.workers.dev/api/sportsapi/races/$id',
          ));
        }
      }
    }
    return dayEvents;
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
