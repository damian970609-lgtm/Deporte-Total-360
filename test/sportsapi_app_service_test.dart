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
            {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League', 'NWSL']},
            {'id': 'basketball', 'name': 'Baloncesto', 'competitions': ['NBA']},
            {'id': 'baseball', 'name': 'Béisbol', 'competitions': ['Major League Baseball']},
            {'id': 'ice-hockey', 'name': 'Hockey sobre hielo', 'competitions': ['NHL']},
            {'id': 'volleyball', 'name': 'Voleibol', 'competitions': ['Volleyball Nations League']},
            {'id': 'mma', 'name': 'MMA', 'competitions': ['UFC']},
            {'id': 'futsal', 'name': 'Fútbol sala', 'competitions': ['FIFA Futsal World Cup']},
            {'id': 'cycling', 'name': 'Ciclismo', 'competitions': ['Tour de France']},
            {'id': 'motorsport', 'name': 'Deportes de motor', 'competitions': ['Formula 1']},
            {'id': 'handball', 'name': 'Balonmano', 'competitions': ["IHF Men's World Championship"]}
          ]
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures') &&
          request.url.queryParameters['sport'] == 'football' &&
          request.url.queryParameters['page'] == '1') {
        return http.Response(jsonEncode({
          'data': [{
            'id': 103,
            'sport': 'football',
            'startTime': '2030-01-01T14:00:00Z',
            'status': {'type': 'scheduled', 'description': 'Not started'},
            'home': {'id': 5, 'name': 'Team Five'},
            'away': {'id': 6, 'name': 'Team Six'},
            'league': {'id': 12, 'name': 'NWSL'},
            'season': {'id': 20, 'name': '2030'}
          }],
          'meta': {'count': 1, 'hasNextPage': false}
        }), 200);
      }
      if (request.url.path.endsWith('/fixtures')) {
        if (request.url.queryParameters['sport'] != 'football') {
          return http.Response(jsonEncode({'data': [], 'meta': {'count': 0}}), 200);
        }
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 101,
              'sport': 'football',
              'startTime': '2030-01-01T12:00:00Z',
              'status': {'type': 'scheduled', 'description': 'Not started'},
              'home': {'id': 1, 'name': 'Team One', 'image': 'https://cdn.example/home.png'},
              'away': {'id': 2, 'name': 'Team Two', 'image': 'https://cdn.example/away.png'},
              'league': {'id': 10, 'name': 'Premier League'},
              'season': {'id': 20, 'name': '2030'}
            },
            {
              'id': 102,
              'sport': 'football',
              'startTime': '2030-01-01T13:00:00Z',
              'status': {'type': 'scheduled', 'description': 'Not started'},
              'home': {'id': 3, 'name': 'Team Three'},
              'away': {'id': 4, 'name': 'Team Four'},
              'league': {'id': 11, 'name': 'Championship'},
              'season': {'id': 20, 'name': '2030'}
            }
          ],
          'meta': {'count': 2, 'hasNextPage': request.url.queryParameters['page'] == '0'}
        }), 200);
      }
      if (request.url.path.endsWith('/races')) {
        if (request.url.queryParameters['sport'] != 'cycling') {
          return http.Response(jsonEncode({'data': [], 'meta': {'count': 0}}), 200);
        }
        return http.Response(jsonEncode({
          'data': [
            {
              'id': 202,
              'name': 'Tour de France',
              'sport': 'cycling',
              'startDate': '2030-01-01',
              'status': 'scheduled',
              'series': {'id': 30, 'name': 'Cycling Men'},
              'season': {'id': 40, 'name': '2030'},
              'sessions': [{'id': 303, 'type': 'stage', 'startTime': '2030-01-01T09:00:00Z'}]
            },
            {
              'id': 203,
              'name': 'Paris-Nice',
              'sport': 'cycling',
              'startDate': '2030-01-01',
              'status': 'scheduled',
              'series': {'id': 30, 'name': 'Cycling Men'},
              'season': {'id': 40, 'name': '2030'},
              'sessions': [{'id': 304, 'type': 'stage', 'startTime': '2030-01-01T10:00:00Z'}]
            }
          ],
          'meta': {'count': 2}
        }), 200);
      }
      return http.Response(jsonEncode({'data': {}, 'meta': {}}), 200);
    });

    try {
      final api = SportsApiAppService(client: client);
      final favorites = await api.fetchFavoriteSports();
      expect(favorites, hasLength(10));
      expect(favorites.any((sport) => sport['id'] == 'football'), isTrue);
      expect(favorites.any((sport) => sport['id'] == 'cycling'), isTrue);

      final events = await api.fetchFavoriteAgendaEvents(date: DateTime.utc(2030, 1, 1));
      expect(events.map((event) => event.id), contains('sportsapi-fixture-101'));
      expect(events.map((event) => event.id), contains('sportsapi-race-202-303'));
      expect(events.map((event) => event.id), isNot(contains('sportsapi-fixture-102')));
      expect(events.map((event) => event.id), isNot(contains('sportsapi-race-203-304')));
      expect(events.firstWhere((event) => event.id == 'sportsapi-race-202-303').competition, 'Tour de France');
      expect(events.firstWhere((event) => event.id == 'sportsapi-fixture-101').homeTeam, 'Team One');
      expect(requested.where((uri) => uri.path.endsWith('/fixtures')), hasLength(9));
      expect(
        requested.where((uri) =>
            uri.path.endsWith('/fixtures') &&
            uri.queryParameters['sport'] == 'football' &&
            uri.queryParameters['page'] == '1'),
        hasLength(1),
      );
      expect(events.map((event) => event.id), contains('sportsapi-fixture-103'));
      expect(requested.where((uri) => uri.path.endsWith('/races')), hasLength(2));
      expect(requested.where((uri) => uri.path.endsWith('/favorites')), hasLength(2));
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
