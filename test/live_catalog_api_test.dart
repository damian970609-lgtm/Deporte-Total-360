import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  late http.Client client;

  setUp(() {
    sportsApiBaseUrl.value = 'https://worker.example';
    SportsApiService.resetForTesting();
  });

  tearDown(() {
    client.close();
    SportsApiService.clientOverride = null;
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
    SportsApiService.resetForTesting();
  });

  test('consulta señales autorizadas del deporte y rango seleccionado', () async {
    client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/live/sources');
      expect(request.url.queryParameters['sport'], 'football');
      expect(request.url.queryParameters['timezone'], 'America/Guyana');
      expect(request.url.queryParameters['from'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(request.url.queryParameters['to'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      return http.Response(
        jsonEncode(<String, Object>{
          'configured': true,
          'count': 1,
          'sources': <Map<String, String>>[
            <String, String>{
              'id': 'fixture-123-main',
              'eventId': '123',
              'sport': 'football',
              'name': 'Señal autorizada',
              'url': 'https://media.example/live.m3u8',
              'startsAt': '2026-11-03T19:00:00Z',
            },
          ],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    SportsApiService.clientOverride = client;

    final rows = await SportsApiService().fetchAuthorizedLiveSources(
      sport: 'Fútbol',
      dateFilter: 'Todos',
    );

    expect(rows, hasLength(1));
    expect(rows.single['eventId'], '123');
    expect(rows.single['url'], 'https://media.example/live.m3u8');
  });

  test('un Worker antiguo sin la ruta de catálogo produce una lista vacía', () async {
    client = MockClient((request) async => http.Response('not found', 404));
    SportsApiService.clientOverride = client;

    final rows = await SportsApiService().fetchAuthorizedLiveSources(
      sport: 'Fútbol',
      dateFilter: 'Hoy',
    );

    expect(rows, isEmpty);
  });

  test('deportes sin ID de Worker no generan solicitudes', () async {
    var requestCount = 0;
    client = MockClient((request) async {
      requestCount++;
      return http.Response('{}', 200);
    });
    SportsApiService.clientOverride = client;

    final rows = await SportsApiService().fetchAuthorizedLiveSources(
      sport: 'Tenis',
      dateFilter: 'Hoy',
    );

    expect(rows, isEmpty);
    expect(requestCount, 0);
  });
}
