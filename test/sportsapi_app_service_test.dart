import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sportsapi_app_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
            {'id': 'cycling', 'name': 'Ciclismo', 'competitions': ['Cycling Men']}
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
        return http.Response(jsonEncode({
          'data': [{
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
          }],
          'meta': {'count': 1}
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
      expect(events.firstWhere((event) => event.id == 'sportsapi-fixture-101').homeTeam, 'Team One');
      expect(requested.where((uri) => uri.path.endsWith('/fixtures')), hasLength(1));
      expect(requested.where((uri) => uri.path.endsWith('/races')), hasLength(1));
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
      final window = await api.fetchFavoriteAgendaWindow(
        startDate: start,
        days: 7,
      );

      expect(window.days, 7);
      expect(window.unavailableDates, isEmpty);
      expect(window.events, hasLength(14));
      expect(window.events.map((event) => event.id).toSet(), hasLength(14));
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

  test('solicita estadísticas por la ruta correcta de SportsAPI', () async {
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker.example';
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(jsonEncode({'data': {'periods': []}, 'meta': {}}), 200);
    });
    try {
      final result = await SportsApiAppService(client: client).fetchFixtureStatistics(101);
      expect(result, isA<Map>());
      expect(requested?.path, '/api/sportsapi/fixtures/101/statistics');
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });
}
