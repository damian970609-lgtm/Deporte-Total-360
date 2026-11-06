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
  });

  final DateTime date;
  final List<SportsAgendaEvent> events;
  final bool failed;
}

class SportsApiAppService {
  SportsApiAppService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String route, [Map<String, String> query = const <String, String>{}]) {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) {
      throw const SportsApiException('La URL del servidor deportivo no es válida.');
    }
    return Uri.parse('$base/api/sportsapi$route').replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<dynamic> _get(String route, [Map<String, String> query = const <String, String>{}]) async {
    try {
      final response = await _client.get(
        _uri(route, query),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        String message = 'El servidor SportsAPI respondió HTTP ${response.statusCode}.';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error['error'] != null) {
            final value = error['error'];
            message = value is Map
                ? (value['message'] ?? value['code'] ?? message).toString()
                : value.toString();
          }
        } catch (_) {
          // Conserva el código HTTP si el servidor no devuelve JSON.
        }
        throw SportsApiException(message);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SportsApiException('La respuesta de SportsAPI no tiene el formato esperado.');
      }
      if (route == '/favorites') return decoded;
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
  static final Map<String, ({
    SportsAgendaWindow window,
    DateTime expiresAt,
  })> _agendaWindowCache =
      <String, ({SportsAgendaWindow window, DateTime expiresAt})>{};
  static final Map<String, Future<SportsAgendaWindow>> _agendaWindowInFlight =
      <String, Future<SportsAgendaWindow>>{};


  Future<List<SportsAgendaEvent>> fetchFavoriteAgendaEvents({
    DateTime? date,
  }) {
    // SportsAPI date is a UTC calendar day. Use the phone's calendar
    // date deliberately so the native Agenda tab stays aligned with the
    // user's local day; returned instants are converted to local time below.
    final selected = date ?? DateTime.now();
    final day = selected.year.toString().padLeft(4, '0') + '-' +
        selected.month.toString().padLeft(2, '0') + '-' +
        selected.day.toString().padLeft(2, '0');
    final cached = _agendaCache[day];
    final expires = _agendaCacheExpiry[day];
    if (cached != null && expires != null && DateTime.now().isBefore(expires)) {
      return Future<List<SportsAgendaEvent>>.value(cached);
    }
    final pending = _agendaInFlight[day];
    if (pending != null) return pending;
    final future = _fetchFavoriteAgendaEvents(day);
    _agendaInFlight[day] = future;
    return future.then((events) {
      _agendaCache[day] = events;
      _agendaCacheExpiry[day] = DateTime.now().add(const Duration(minutes: 2));
      return events;
    }).whenComplete(() {
      _agendaInFlight.remove(day);
    });
  }

  /// Descarga hoy y los seis días siguientes. Se consultan dos fechas a la
  /// vez para limitar el número de conexiones concurrentes al Worker.
  Future<SportsAgendaWindow> fetchFavoriteAgendaWindow({
    DateTime? startDate,
    int days = 7,
  }) {
    final requested = startDate ?? DateTime.now();
    final firstDay = DateTime(requested.year, requested.month, requested.day);
    final safeDays = days.clamp(1, 7).toInt();
    final firstKey = '\${firstDay.year.toString().padLeft(4, '0')}-'
        '\${firstDay.month.toString().padLeft(2, '0')}-'
        '\${firstDay.day.toString().padLeft(2, '0')}';
    final cacheKey = '$firstKey:$safeDays';
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
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
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
    final resultsById = <String, SportsAgendaEvent>{};
    final unavailableDates = <DateTime>[];

    for (var batchStart = 0; batchStart < days; batchStart += 2) {
      final batchLength = (days - batchStart) < 2 ? days - batchStart : 2;
      final dates = List<DateTime>.generate(
        batchLength,
        (index) => startDate.add(Duration(days: batchStart + index)),
        growable: false,
      );
      final batch = await Future.wait<_AgendaDayResult>(
        dates.map((date) async {
          try {
            final rows = await fetchFavoriteAgendaEvents(date: date);
            return _AgendaDayResult(date: date, events: rows);
          } catch (_) {
            return _AgendaDayResult(
              date: date,
              events: const <SportsAgendaEvent>[],
              failed: true,
            );
          }
        }),
      );
      for (final result in batch) {
        if (result.failed) {
          unavailableDates.add(result.date);
          continue;
        }
        for (final event in result.events) {
          resultsById[event.id] = event;
        }
      }
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = start.add(Duration(days: days));
    final events = resultsById.values.where((event) {
      final localStart = event.startsAt.toLocal();
      return !localStart.isBefore(start) && localStart.isBefore(end);
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return SportsAgendaWindow(
      startDate: start,
      days: days,
      events: events,
      unavailableDates: unavailableDates,
    );
  }

  Future<List<SportsAgendaEvent>> _fetchFavoriteAgendaEvents(String day) async {
    var successfulSports = 0;
    final results = await Future.wait(_sportNames.entries.map((entry) async {
      try {
        final isRace = entry.key == 'cycling' || entry.key == 'motorsport';
        final payload = await _get(
          isRace ? '/races' : '/fixtures',
          <String, String>{'date': day, 'sport': entry.key, if (!isRace) 'page': '0'},
        );
        if (payload is! List) {
          throw const FormatException('SportsAPI devolvió una agenda con formato inválido.');
        }
        successfulSports++;
        return payload.whereType<Map>().map((raw) {
          final row = Map<String, dynamic>.from(raw);
          if (isRace) return _raceEvent(row, entry.key, entry.value);
          return _fixtureEvent(row, entry.value);
        }).whereType<SportsAgendaEvent>().toList(growable: false);
      } catch (_) {
        // La falta de cobertura de un deporte no bloquea los demás.
        return <SportsAgendaEvent>[];
      }
    }));

    if (successfulSports == 0) {
      throw const SportsApiException('No se pudo consultar ninguno de tus diez deportes favoritos en SportsAPI.');
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
    String sportName,
  ) {
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
      competition: _text(series['name']),
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
