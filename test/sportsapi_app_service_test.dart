import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sportsapi_app_service.dart';
import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una respuesta del Worker sin lista de favoritos se trata como fallo y no como lista vacía', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-malformed-favorites.example';
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'status': 'ok'}), 200);
    });
    try {
      await expectLater(
        SportsApiAppService(client: client).fetchFavoriteAgendaSportNames(),
        throwsA(isA<SportsApiException>()),
      );
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('lista todos los deportes favoritos aunque no tengan encuentros publicados', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-favorite-catalog.example';
    var fixtureRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']},
            {'id': 'basketball', 'name': 'Baloncesto', 'competitions': ['NBA']},
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) fixtureRequests++;
      return http.Response(jsonEncode({'data': [], 'meta': {'hasNextPage': false}}), 200);
    });
    try {
      final names = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaSportNames();
      expect(names, ['Baloncesto', 'Fútbol']);
      expect(fixtureRequests, 0);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('carga favoritos y eventos de equipo y carreras desde SportsAPI', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker.example';
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']},
            {'id': 'cycling', 'name': 'Ciclismo', 'competitions': ['Tour de France']}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        if (request.url.queryParameters['sport'] != 'football') {
          return http.Response(jsonEncode({'data': [], 'meta': {'count': 0}}), 200);
        }
        return http.Response(jsonEncode({
          'data': [{
            'id': 101,
            'sport': 'football',
            'startTime': '2030-01-01T12:00:00Z',
            'status': {'type': 'scheduled', 'description': 'Not started'},
            'home': {'id': 1, 'name': 'Team One', 'image': 'https://cdn.example/home.png'},
            'away': {'id': 2, 'name': 'Team Two', 'image': 'https://cdn.example/away.png'},
            'league': {'id': 10, 'name': 'Premier League'},
            'season': {'id': 20, 'name': '2030'}
          }],
          'meta': {'count': 1, 'hasNextPage': false, 'complete': true}
        }), 200);
      }
      if (request.url.path.endsWith('/races')) {
        if (request.url.queryParameters['sport'] != 'cycling') {
          return http.Response(jsonEncode({'data': [], 'meta': {'count': 0}}), 200);
        }
        final page = int.parse(request.url.queryParameters['page'] ?? '0');
        final rows = page == 0
            ? [{
                'id': 202,
                'name': 'Tour de France',
                'sport': 'cycling',
                'startDate': '2030-01-01',
                'status': 'scheduled',
                'series': {'id': 30, 'name': 'Cycling Men'},
                'season': {'id': 40, 'name': '2030'},
                'sessions': [
                  {'id': 303, 'type': 'practice', 'startTime': '2030-01-01T09:00:00Z'},
                  {'id': 304, 'type': 'stage', 'startTime': '2030-01-01T12:00:00Z'}
                ]
              }]
            : page == 1
                ? [{
                    'id': 203,
                    'name': 'Tour de France',
                    'sport': 'cycling',
                    'startDate': '2030-01-01',
                    'status': 'scheduled',
                    'series': {'id': 30, 'name': 'Cycling Men'},
                    'season': {'id': 40, 'name': '2030'},
                    'sessions': [
                      {'id': 305, 'type': 'stage', 'startTime': '2030-01-01T15:00:00Z'}
                    ]
                  }]
                : [];
        return http.Response(jsonEncode({
          'data': rows,
          'meta': {'count': rows.length, 'hasNextPage': page == 0}
        }), 200);
      }
      return http.Response(jsonEncode({'data': {}, 'meta': {}}), 200);
    });

    try {
      final api = SportsApiAppService(client: client);
      final favorites = await api.fetchFavoriteSports();
      expect(favorites, hasLength(2));
      expect(favorites.first['id'], 'football');

      final events = await api.fetchFavoriteAgendaEvents(date: DateTime.utc(2030, 1, 1));
      expect(events.map((event) => event.id), contains('sportsapi-fixture-101'));
      expect(events.map((event) => event.id), contains('sportsapi-race-202-303'));
      expect(events.map((event) => event.id), contains('sportsapi-race-202-304'));
      expect(events.map((event) => event.id), contains('sportsapi-race-203-305'));
      expect(
        events.firstWhere((event) => event.id == 'sportsapi-race-202-303').competition,
        'Tour de France',
      );
      expect(events.firstWhere((event) => event.id == 'sportsapi-fixture-101').homeTeam, 'Team One');
      expect(requested.where((uri) => uri.path.endsWith('/fixtures')), hasLength(1));
      expect(requested.where((uri) => uri.path.endsWith('/races')), hasLength(2));
      expect(
        requested.where((uri) => uri.path.endsWith('/races')).map((uri) => uri.queryParameters['page']),
        ['0', '1'],
      );
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('consulta solo los deportes favoritos y filtra las competiciones seleccionadas', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-favorite-filter.example';
    final requestedSports = <String>{};
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {
              'id': 'football',
              'name': 'Fútbol',
              'competitions': [
                {'id': 39, 'name': 'Premier League'},
              ],
            },
            {
              'id': 'basketball',
              'name': 'Baloncesto',
              'competitions': ['NBA'],
            },
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        final sport = request.url.queryParameters['sport']!;
        requestedSports.add(sport);
        final rows = sport == 'football'
            ? [
                {
                  'id': 101,
                  'startTime': '2036-05-06T12:00:00Z',
                  'status': {'type': 'scheduled'},
                  'home': {'name': 'Equipo Premier'},
                  'away': {'name': 'Rival Premier'},
                  'league': {'id': 39, 'name': 'Premier League'},
                },
                {
                  'id': 102,
                  'startTime': '2036-05-06T14:00:00Z',
                  'status': {'type': 'scheduled'},
                  'home': {'name': 'Equipo Liga'},
                  'away': {'name': 'Rival Liga'},
                  'league': {'id': 140, 'name': 'La Liga'},
                },
              ]
            : [
                {
                  'id': 201,
                  'startTime': '2036-05-06T16:00:00Z',
                  'status': {'type': 'scheduled'},
                  'home': {'name': 'Equipo NBA'},
                  'away': {'name': 'Rival NBA'},
                  'league': {'id': 12, 'name': 'NBA'},
                },
                {
                  'id': 202,
                  'startTime': '2036-05-06T18:00:00Z',
                  'status': {'type': 'scheduled'},
                  'home': {'name': 'Equipo Euro'},
                  'away': {'name': 'Rival Euro'},
                  'league': {'id': 999, 'name': 'EuroLeague'},
                },
              ];
        return http.Response(jsonEncode({
          'data': rows,
          'meta': {'hasNextPage': false, 'complete': true},
        }), 200);
      }
      if (request.url.path.endsWith('/races')) {
        return http.Response(jsonEncode({
          'data': [],
          'meta': {'complete': true},
        }), 200);
      }
      return http.Response('{}', 404);
    });

    try {
      final api = SportsApiAppService(client: client);
      final events = await api.fetchFavoriteAgendaEvents(
        date: DateTime.utc(2036, 5, 6),
      );
      expect(requestedSports, {'football', 'basketball'});
      expect(events.map((event) => event.id).toSet(), {
        'sportsapi-fixture-101',
        'sportsapi-fixture-201',
      });
      expect(events.map((event) => event.competition).toSet(), {
        'Premier League',
        'NBA',
      });
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('combina la lista vacía de competiciones con las ligas seleccionadas y acepta mapas por ID', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-selection-shapes.example';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {
              'id': 'football',
              'name': 'Fútbol',
              'competitions': [],
              'selectedCompetitions': [
                {'leagueId': 39, 'leagueName': 'Premier League'},
              ],
            },
            {
              'id': 'basketball',
              'name': 'Baloncesto',
              'competitions': {'12': true, '999': false},
            },
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        final sport = request.url.queryParameters['sport'];
        final rows = sport == 'football'
            ? [
                {'id': 301, 'startTime': '2036-05-07T12:00:00Z',
                 'status': {'type': 'scheduled'}, 'home': {'name': 'Premier'},
                 'away': {'name': 'Rival'}, 'league': {'id': 39, 'name': 'Premier League'}},
                {'id': 302, 'startTime': '2036-05-07T14:00:00Z',
                 'status': {'type': 'scheduled'}, 'home': {'name': 'Otra liga'},
                 'away': {'name': 'Rival'}, 'league': {'id': 140, 'name': 'Otra liga'}},
              ]
            : [
                {'id': 401, 'startTime': '2036-05-07T16:00:00Z',
                 'status': {'type': 'scheduled'}, 'home': {'name': 'NBA'},
                 'away': {'name': 'Rival'}, 'league': {'id': 12, 'name': 'NBA'}},
                {'id': 402, 'startTime': '2036-05-07T18:00:00Z',
                 'status': {'type': 'scheduled'}, 'home': {'name': 'Otra liga'},
                 'away': {'name': 'Rival'}, 'league': {'id': 999, 'name': 'Otra liga'}},
              ];
        return http.Response(jsonEncode({
          'data': rows, 'meta': {'hasNextPage': false, 'complete': true},
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': [], 'meta': {'hasNextPage': false, 'complete': true},
      }), 200);
    });

    try {
      final events = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaEvents(date: DateTime.utc(2036, 5, 7));
      expect(events.map((event) => event.id).toSet(), {
        'sportsapi-fixture-301', 'sportsapi-fixture-401',
      });
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('vuelve a filtrar el respaldo del Worker para no mostrar ligas ajenas', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-favorite-fallback.example';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {
              'id': 'football',
              'name': 'Fútbol',
              'competitions': ['Premier League'],
            },
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 601,
              'startTime': '2036-06-01T12:00:00Z',
              'status': {'type': 'scheduled'},
              'home': {'name': 'Equipo favorito'},
              'away': {'name': 'Rival'},
              'league': {'id': 39, 'name': 'Premier League'},
            },
            {
              'id': 602,
              'startTime': '2036-06-01T13:00:00Z',
              'status': {'type': 'scheduled'},
              'home': {'name': 'Equipo no favorito'},
              'away': {'name': 'Rival'},
              'league': {'id': 999, 'name': 'Domestic Premier Competition'},
            },
          ],
          'meta': {
            'hasNextPage': false,
            'complete': true,
            'favoriteCompetitionFilter': false,
            'favoriteCompetitionFilterFallback': true,
          },
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': [],
        'meta': {'hasNextPage': false, 'complete': true},
      }), 200);
    });

    try {
      final events = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaEvents(date: DateTime.utc(2036, 6, 1));
      expect(events.map((event) => event.id), ['sportsapi-fixture-601']);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('un deporte favorito sin ligas seleccionadas no carga competiciones', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-empty-selection.example';
    var fixtureRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'data': {'sports': [{'id': 'football', 'name': 'Fútbol'}]},
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        fixtureRequests++;
        return http.Response(jsonEncode({
          'data': [{
            'id': 501, 'startTime': '2036-05-08T12:00:00Z',
            'status': {'type': 'scheduled'}, 'home': {'name': 'Equipo A'},
            'away': {'name': 'Equipo B'},
            'league': {'id': 39, 'name': 'Premier League'},
          }],
          'meta': {'hasNextPage': false, 'complete': true},
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': [], 'meta': {'hasNextPage': false, 'complete': true},
      }), 200);
    });

    try {
      final events = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaEvents(date: DateTime.utc(2036, 5, 8));
      expect(events, isEmpty);
      expect(fixtureRequests, 0);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('consulta fechas UTC de la semana en serie para respetar la cuota', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-window-concurrency.example';
    String? firstDate;
    var firstDateFinished = false;
    var anotherDateStartedBeforeFinish = false;
    final startedDates = <String>{};
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Liga de prueba']},
          ],
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        final date = request.url.queryParameters['date']!;
        firstDate ??= date;
        startedDates.add(date);
        if (date != firstDate && !firstDateFinished) {
          anotherDateStartedBeforeFinish = true;
        }
        if (date == firstDate) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          firstDateFinished = true;
        }
        return http.Response(jsonEncode({
          'data': [],
          'meta': {'hasNextPage': false, 'complete': true},
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': [],
        'meta': {'complete': true},
      }), 200);
    });

    try {
      final window = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaWindow(
        startDate: DateTime(2041, 5, 6),
        days: 7,
      );
      expect(window.days, 7);
      expect(startedDates.length, greaterThan(1));
      expect(anotherDateStartedBeforeFinish, isFalse);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('carga y reutiliza la ventana de los próximos siete días', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-window.example';
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Liga de prueba']}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        if (request.url.queryParameters['sport'] != 'football') {
          return http.Response(jsonEncode({'data': [], 'meta': {'hasNextPage': false, 'complete': true}}), 200);
        }
        final date = request.url.queryParameters['date']!;
        final page = int.parse(request.url.queryParameters['page'] ?? '0');
        final day = int.parse(date.substring(8));
        return http.Response(jsonEncode({
          'data': [{
            'id': day * 10 + page,
            'sport': 'football',
            'startTime': date + 'T12:00:00Z',
            'status': {'type': 'scheduled'},
            'home': {'id': day * 20 + page * 2, 'name': 'Equipo ' + day.toString() + ' ' + page.toString()},
            'away': {'id': day * 20 + page * 2 + 1, 'name': 'Rival ' + day.toString() + ' ' + page.toString()},
            'league': {'id': 1, 'name': 'Liga de prueba'},
          }],
          'meta': {'count': 1, 'hasNextPage': page == 0, 'complete': true}
        }), 200);
      }
      if (request.url.path.endsWith('/races')) {
        return http.Response(jsonEncode({'data': [], 'meta': {'complete': true}}), 200);
      }
      return http.Response(jsonEncode({'data': {}, 'meta': {}}), 200);
    });

    try {
      final api = SportsApiAppService(client: client);
      final start = DateTime(2031, 2, 3);
      final progressEventCounts = <int>[];
      final window = await api.fetchFavoriteAgendaWindow(
        startDate: start,
        days: 7,
        onProgress: (partial) => progressEventCounts.add(partial.events.length),
      );

      expect(window.days, 7);
      expect(window.unavailableDates, isEmpty);
      expect(window.events, hasLength(14));
      expect(window.events.map((event) => event.id).toSet(), hasLength(14));
      expect(progressEventCounts, isNotEmpty);
      expect(progressEventCounts.any((count) => count > 0), isTrue);
      final localStart = DateTime(start.year, start.month, start.day);
      final localEnd = localStart.add(const Duration(days: 7));
      final firstUtc = localStart.toUtc();
      final lastUtc = localEnd.toUtc().subtract(
        const Duration(milliseconds: 1),
      );
      final firstUtcDay = DateTime.utc(firstUtc.year, firstUtc.month, firstUtc.day);
      final lastUtcDay = DateTime.utc(lastUtc.year, lastUtc.month, lastUtc.day);
      final utcDays = lastUtcDay.difference(firstUtcDay).inDays + 1;
      final eventLocalDays = window.events.map((event) {
        final local = event.startsAt.toLocal();
        return '${local.year}-${local.month}-${local.day}';
      }).toSet();
      expect(eventLocalDays, hasLength(7));
      expect(
        eventLocalDays,
        contains('${localStart.year}-${localStart.month}-${localStart.day}'),
      );
      expect(
        requested.where((uri) => uri.path.endsWith('/fixtures')),
        hasLength(utcDays * 2),
      );
      expect(
        requested.where((uri) => uri.path.endsWith('/races')),
        hasLength(0),
      );

      final cached = await api.fetchFavoriteAgendaWindow(
        startDate: start,
        days: 7,
      );
      expect(cached.events, hasLength(14));
      expect(requested.where((uri) => uri.path.endsWith('/favorites')), hasLength(1));
      expect(requested, hasLength(utcDays * 2 + 1));

      final refreshed = await api.fetchFavoriteAgendaWindow(
        startDate: start,
        days: 7,
        forceRefresh: true,
      );
      expect(refreshed.events, hasLength(14));
      expect(requested.where((uri) => uri.queryParameters['refresh'] == '1'), isNotEmpty);
      expect(requested.where((uri) => uri.path.endsWith('/favorites')), hasLength(2));
      expect(requested, hasLength(utcDays * 4 + 2));
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('marca cobertura parcial si falla un deporte sin descartar los demás', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-partial.example';
    final failedDate = '2033-03-04';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Liga de prueba']},
            {'id': 'basketball', 'name': 'Baloncesto', 'competitions': ['Liga de prueba']}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        final date = request.url.queryParameters['date']!;
        final sport = request.url.queryParameters['sport'];
        if (date == failedDate && sport == 'basketball') {
          return http.Response(
            jsonEncode({'error': 'basketball temporarily unavailable'}),
            503,
          );
        }
        final rows = date == failedDate && sport == 'football'
            ? [{
                'id': 404,
                'sport': 'football',
                'startTime': failedDate + 'T12:00:00Z',
                'status': {'type': 'scheduled'},
                'home': {'id': 1, 'name': 'Equipo A'},
                'away': {'id': 2, 'name': 'Equipo B'},
                'league': {'id': 1, 'name': 'Liga de prueba'},
              }]
            : <Map<String, dynamic>>[];
        return http.Response(jsonEncode({
          'data': rows,
          'meta': {'hasNextPage': false, 'complete': true},
        }), 200);
      }
      if (request.url.path.endsWith('/races')) {
        return http.Response(jsonEncode({
          'data': [],
          'meta': {'complete': true},
        }), 200);
      }
      return http.Response(jsonEncode({'data': {}, 'meta': {}}), 200);
    });

    try {
      final window = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaWindow(
        startDate: DateTime(2033, 3, 4),
        days: 7,
      );
      expect(
        window.unavailableDates.any((date) =>
            date.year == 2033 && date.month == 3 && date.day == 4),
        isTrue,
      );
      expect(window.events, hasLength(1));
      expect(window.events.single.id, 'sportsapi-fixture-404');
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('no reintenta límites 429 con Retry-After largo y conserva datos parciales', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-rate-limit.example';
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Liga de prueba']}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures') &&
          request.url.queryParameters['sport'] == 'football') {
        return http.Response(
          jsonEncode(<String, Object>{
            'error': 'API limit reached',
          }),
          429,
          headers: <String, String>{'retry-after': '60'},
        );
      }
      if (request.url.path.endsWith('/fixtures')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'data': <Object>[],
            'meta': <String, Object>{
              'hasNextPage': false,
              'complete': true,
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/races')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'data': <Object>[],
            'meta': <String, Object>{'complete': true},
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    try {
      final start = DateTime(2035, 4, 5);
      final localStart = DateTime(start.year, start.month, start.day);
      final localEnd = localStart.add(const Duration(days: 1));
      final firstUtc = localStart.toUtc();
      final lastUtc = localEnd.toUtc().subtract(
        const Duration(milliseconds: 1),
      );
      final firstUtcDay = DateTime.utc(
        firstUtc.year,
        firstUtc.month,
        firstUtc.day,
      );
      final lastUtcDay = DateTime.utc(
        lastUtc.year,
        lastUtc.month,
        lastUtc.day,
      );
      final expectedUtcDays = lastUtcDay.difference(firstUtcDay).inDays + 1;

      final window = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaWindow(startDate: start, days: 1);

      final footballRequests = requested.where(
        (uri) =>
            uri.path.endsWith('/fixtures') &&
            uri.queryParameters['sport'] == 'football',
      );

      expect(footballRequests, hasLength(expectedUtcDays));
      expect(window.events, isEmpty);
      expect(window.unavailableDates, isNotEmpty);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('las cuatro consultas de estadísticas usan rutas e identificadores correctos', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-statistics-endpoints.example';
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response(
        jsonEncode({'data': <dynamic>[], 'meta': <String, dynamic>{}}),
        200,
      );
    });
    try {
      final api = SportsApiAppService(client: client);
      await api.fetchFixtureStatistics(101);
      await api.fetchRaceResults(202, sessionId: 303);
      await api.fetchLeagueStandings(leagueId: 39, seasonId: 2026);
      await api.fetchSeriesStandings(seriesId: 55, seasonId: 2026);

      expect(requested.map((uri) => uri.path), <String>[
        '/api/sportsapi/fixtures/101/statistics',
        '/api/sportsapi/races/202/results',
        '/api/sportsapi/leagues/39/standings',
        '/api/sportsapi/series/55/standings',
      ]);
      expect(requested[1].queryParameters, <String, String>{'session': '303'});
      expect(requested[2].queryParameters, <String, String>{'season': '2026'});
      expect(requested[3].queryParameters, <String, String>{
        'season': '2026',
        'type': 'competitors',
      });
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });
  test('acepta variantes del nombre de una liga favorita sin perder el evento', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-league-alias.example';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {
              'id': 'football',
              'name': 'Fútbol',
              'competitions': ['LaLiga EA SPORTS'],
              'competitionAliases': {'LaLiga EA SPORTS': ['LaLiga', 'La Liga']},
            }
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        return http.Response(jsonEncode({
          'data': [{
            'id': 303,
            'sport': 'football',
            'startTime': '2030-01-01T12:00:00Z',
            'home': {'name': 'Equipo A'},
            'away': {'name': 'Equipo B'},
            'league': {'id': 140, 'name': 'La Liga'},
            'season': {'id': 2030},
            'status': {'type': 'scheduled'}
          }],
          'meta': {'complete': true, 'hasNextPage': false}
        }), 200);
      }
      return http.Response(jsonEncode({'data': []}), 200);
    });

    try {
      final api = SportsApiAppService(client: client);
      final events = await api.fetchFavoriteAgendaEvents(
        date: DateTime.utc(2030, 1, 1),
      );
      expect(events, hasLength(1));
      expect(events.single.id, 'sportsapi-fixture-303');
      expect(events.single.competition, 'La Liga');
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });


  test('recupera el catálogo de deportes favoritos desde SharedPreferences si falla el Worker', () async {
    SharedPreferences.setMockInitialValues({});
    final previousBase = sportsApiBaseUrl.value;
    const base = 'https://worker-favorites-offline.example';
    sportsApiBaseUrl.value = base;
    final firstClient = MockClient((request) async => http.Response(jsonEncode({
      'sports': [
        {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']},
        {'id': 'basketball', 'name': 'Baloncesto', 'competitions': ['NBA']}
      ]
    }), 200));
    final failedClient = MockClient((request) async => http.Response('{}', 503));
    try {
      final first = SportsApiAppService(client: firstClient);
      final saved = await first.fetchFavoriteSports();
      expect(saved, hasLength(2));

      final offline = await SportsApiAppService(client: failedClient)
          .fetchFavoriteSports(forceRefresh: true);
      expect(offline.map((item) => item['id']), ['football', 'basketball']);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      firstClient.close();
      failedClient.close();
    }
  });

  test('recupera la agenda guardada si todas las consultas del Worker fallan', () async {
    SharedPreferences.setMockInitialValues({});
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-agenda-offline.example';
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final saved = SportsAgendaEvent(
      id: 'sportsapi-fixture-offline-202',
      title: 'Equipo Uno vs Equipo Dos',
      sport: 'Fútbol',
      competition: 'Premier League',
      homeTeam: 'Equipo Uno',
      awayTeam: 'Equipo Dos',
      startsAt: start.add(const Duration(hours: 14)),
      detailUrl: 'https://deporte-total-360-api.example/api/sportsapi/fixtures/202',
    );
    await SportsAgendaStore.saveWindow(
      <SportsAgendaEvent>[saved],
      startDate: start,
      days: 1,
    );
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']}
          ]
        }), 200);
      }
      return http.Response(jsonEncode({'error': {'message': 'quota'}}), 503,
          headers: {'retry-after': '30'});
    });
    try {
      final window = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaWindow(startDate: start, days: 1);
      expect(window.events.map((event) => event.id), contains(saved.id));
      expect(window.unavailableDates, isNotEmpty);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });


  test('las estadísticas de un partido se guardan por jornada y solo refrescan al vencer o forzar', () async {
    SharedPreferences.setMockInitialValues({});
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-daily-statistics-cache.example';
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response(
        jsonEncode({
          'data': {
            'periods': [
              {
                'name': 'Partido',
                'groups': [
                  {
                    'name': 'General',
                    'items': [
                      {'name': 'Posesión', 'home': '55%', 'away': '45%'},
                    ],
                  },
                ],
              },
            ],
          },
          'meta': {},
        }),
        200,
      );
    });

    try {
      final api = SportsApiAppService(client: client);
      final today = DateTime.now();
      final first = await api.fetchFixtureStatistics(101, eventDate: today);
      final cached = await api.fetchFixtureStatistics(101, eventDate: today);
      expect(first, cached);
      expect(requested, hasLength(1));

      await api.fetchFixtureStatistics(
        101,
        eventDate: today,
        forceRefresh: true,
      );
      expect(requested, hasLength(2));
      expect(requested.last.queryParameters['refresh'], '1');
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });


  test('conserva los eventos de la primera página cuando la siguiente responde 429', () async {
    SharedPreferences.setMockInitialValues({});
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-partial-page-429.example';
    final requestedPages = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/favorites')) {
        return http.Response(jsonEncode({
          'sports': [
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Liga de prueba']}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        final date = request.url.queryParameters['date']!;
        final page = request.url.queryParameters['page'] ?? '0';
        requestedPages.add('$date:$page');
        if (page == '1') {
          return http.Response(
            jsonEncode({'error': {'code': 'rate_limited', 'message': 'Too many requests'}}),
            429,
            headers: {'retry-after': '60'},
          );
        }
        return http.Response(jsonEncode({
          'data': [{
            'id': date.replaceAll('-', ''),
            'startTime': '${date}T12:00:00Z',
            'status': {'type': 'scheduled'},
            'home': {'name': 'Equipo de prueba'},
            'away': {'name': 'Rival de prueba'},
            'league': {'id': 1, 'name': 'Liga de prueba'},
          }],
          'meta': {'hasNextPage': true, 'complete': true},
        }), 200);
      }
      return http.Response(jsonEncode({'data': [], 'meta': {}}), 200);
    });

    try {
      final window = await SportsApiAppService(client: client)
          .fetchFavoriteAgendaWindow(
        startDate: DateTime(2037, 6, 10),
        days: 1,
      );
      expect(requestedPages, isNotEmpty);
      expect(requestedPages.any((page) => page.endsWith(':0')), isTrue);
      expect(requestedPages.any((page) => page.endsWith(':1')), isTrue);
      expect(window.events, isNotEmpty);
      expect(
        window.events.any((event) => event.title.contains('Equipo de prueba')),
        isTrue,
      );
      expect(window.unavailableDates, isNotEmpty);
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });


}
