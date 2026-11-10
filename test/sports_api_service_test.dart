import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  group('SportsApiService', () {
    setUp(() {
      SportsApiService.clientOverride = null;
      SportsApiService.resetForTesting();
      sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
    });

    tearDown(() {
      SportsApiService.clientOverride = null;
      SportsApiService.resetForTesting();
      sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
    });
    test('expone las doce categorías multideporte configuradas', () {
      expect(SportsApiService.supportedSports.length, 12);
      expect(SportsApiService.supportedSports['Fútbol'], 'football');
      expect(SportsApiService.supportedSports['NBA'], 'nba');
      expect(SportsApiService.supportedSports['Fútbol americano'], 'american-football');
      expect(SportsApiService.supportedSports['Fórmula 1'], 'formula-1');
      expect(SportsApiService.supportedSports['MMA'], 'mma');
    });


    test('comprueba que el Worker esté online y con proveedor configurado', () async {
      SportsApiService.clientOverride = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'status': 'online',
            'provider_configured': true,
            'sports': 12,
          }),
          200,
        );
      });

      await SportsApiService().checkHealth('https://worker.example');
    });

    test('no considera saludable un Worker sin clave API', () async {
      SportsApiService.clientOverride = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'status': 'online',
            'provider_configured': false,
          }),
          200,
        );
      });

      await expectLater(
        SportsApiService().checkHealth('https://worker.example'),
        throwsA(
          isA<SportsApiException>().having(
            (error) => error.message,
            'message',
            contains('APISPORTS_KEY'),
          ),
        ),
      );
    });

    test('rechaza un estado HTTP 200 si el Worker no está online', () async {
      SportsApiService.clientOverride = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'status': 'degraded',
            'provider_configured': true,
          }),
          200,
        );
      });

      await expectLater(
        SportsApiService().checkHealth('https://worker.example'),
        throwsA(isA<SportsApiException>()),
      );
    });

    test('muestra el detalle JSON del error HTTP del Worker', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.clientOverride = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'El proveedor devolvió errores',
            'provider_status': 401,
            'details': <String, String>{'token': 'invalid'},
          }),
          502,
        );
      });

      await expectLater(
        SportsApiService().fetchAgendaEvents(
          sport: 'Fútbol',
          dateFilter: 'Hoy',
        ),
        throwsA(
          isA<SportsApiException>().having(
            (error) => error.message,
            'message',
            allOf(contains('token'), contains('401')),
          ),
        ),
      );
    });

    test('normaliza HTTPS y elimina barras finales', () {
      expect(
        SportsApiService.normalizeBaseUrl('  https://example.com/api///  '),
        'https://example.com/api',
      );
    });

    test('rechaza HTTP y URLs con credenciales o parámetros', () {
      expect(SportsApiService.normalizeBaseUrl('http://example.com'), isNull);
      expect(
        SportsApiService.normalizeBaseUrl('https://user:pass@example.com'),
        isNull,
      );
      expect(
        SportsApiService.normalizeBaseUrl('https://example.com?token=x'),
        isNull,
      );
    });

    test('combina los doce deportes en una respuesta etiquetada para el feed Todos', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.minimumRequestIntervalForTesting = Duration.zero;
      final completedSports = <String>[];
      SportsApiService.clientOverride = MockClient((request) async {
        expect(request.url.path, startsWith('/api/'));
        final sportPath = request.url.path.split('/')[2];
        return http.Response(
          jsonEncode(<String, dynamic>{
            'response': <Map<String, dynamic>>[
              <String, dynamic>{
                'fixture': <String, dynamic>{
                  'id': sportPath,
                  'date': '2026-11-03T18:00:00Z',
                  'status': <String, dynamic>{'short': 'NS'},
                },
                'teams': <String, dynamic>{
                  'home': <String, dynamic>{'name': 'Local $sportPath'},
                  'away': <String, dynamic>{'name': 'Visitante $sportPath'},
                },
              },
            ],
            'errors': <String, dynamic>{},
          }),
          200,
        );
      });

      final rows = await SportsApiService().fetchAllAgendaEvents(
        dateFilter: 'Hoy',
        onSportComplete: (sport, sportRows) => completedSports.add(sport),
      );

      expect(rows, hasLength(SportsApiService.supportedSports.length));
      expect(completedSports.toSet(), SportsApiService.supportedSports.keys.toSet());
      expect(rows.map((row) => row['_sportName']).toSet(),
          SportsApiService.supportedSports.keys.toSet());
    });

    test('consulta partidos y devuelve el número de eventos recibidos', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.clientOverride = MockClient((request) async {
        expect(request.url.path, '/api/fixtures');
        expect(request.url.queryParameters['timezone'], 'America/Guyana');
        expect(request.url.queryParameters['from'], isNotEmpty);
        expect(request.url.queryParameters['to'], isNotEmpty);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'response': <Map<String, dynamic>>[
              <String, dynamic>{'fixture': <String, dynamic>{'id': 1}},
              <String, dynamic>{'fixture': <String, dynamic>{'id': 2}},
            ],
            'errors': <String, dynamic>{},
          }),
          200,
        );
      });
      expect(await SportsApiService().checkFootballFixtures(), 2);
    });

    test('restaura eventos desde la caché persistente cuando la conexión falla', () async {
      SharedPreferences.setMockInitialValues({});
      sportsApiBaseUrl.value = 'https://cache-persistente.example';
      var requestCount = 0;
      SportsApiService.clientOverride = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode({
            'errors': <String>[],
            'response': [
              {'fixture': {'id': 9901}, 'league': {'name': 'Liga guardada'}},
            ],
          }), 200);
        }
        throw const http.ClientException('sin conexión');
      });

      final first = await SportsApiService().fetchAgendaEvents(
        sport: 'Fútbol',
        dateFilter: 'Hoy',
      );
      expect(first, isNotEmpty);

      SportsApiService.resetForTesting();
      SportsApiService.clientOverride = MockClient((request) async {
        requestCount++;
        throw const http.ClientException('sin conexión');
      });

      final restored = await SportsApiService().fetchAgendaEvents(
        sport: 'Fútbol',
        dateFilter: 'Hoy',
      );
      expect(restored, isNotEmpty);
      expect(restored.first['fixture']['id'], 9901);
      expect(requestCount, 1, reason: 'La respuesta reciente debe salir de disco sin otra consulta.');
    });

    test('trata HTTP 204 como consulta correcta sin partidos', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.clientOverride = MockClient((request) async {
        return http.Response('', 204);
      });
      expect(await SportsApiService().checkFootballFixtures(), 0);
    });

  });
}
