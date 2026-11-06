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
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']}
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
          'meta': {'count': 1, 'hasNextPage': page == 0, 'complete': true}
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
      expect(favorites, hasLength(1));
      expect(favorites.first['id'], 'football');

      final events = await api.fetchFavoriteAgendaEvents(date: DateTime.utc(2030, 1, 1));
      expect(events.map((event) => event.id), contains('sportsapi-fixture-101'));
      expect(events.map((event) => event.id), contains('sportsapi-race-202-303'));
      expect(events.map((event) => event.id), contains('sportsapi-race-202-304'));
      expect(events.firstWhere((event) => event.id == 'sportsapi-fixture-101').homeTeam, 'Team One');
      expect(requested.where((uri) => uri.path.endsWith('/fixtures')), hasLength(8));
      expect(requested.where((uri) => uri.path.endsWith('/races')), hasLength(2));
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
          'meta': {'count': 1}
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
      expect(requested.where((uri) => uri.path.endsWith('/fixtures')), hasLength(63));
      expect(requested.where((uri) => uri.path.endsWith('/races')), hasLength(14));

      final cached = await api.fetchFavoriteAgendaWindow(
        startDate: start,
        days: 7,
      );
      expect(cached.events, hasLength(7));
      expect(requested, hasLength(77));
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
