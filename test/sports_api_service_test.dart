import 'dart:convert';

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


    test('consulta partidos y devuelve el número de eventos recibidos', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.clientOverride = MockClient((request) async {
        expect(request.url.path, '/api/fixtures');
        expect(request.url.queryParameters['timezone'], 'America/Guyana');
        expect(request.url.queryParameters['from'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}
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
  });
}
)));
        expect(request.url.queryParameters['to'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}
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
  });
}
)));
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

    test('trata HTTP 204 como consulta correcta sin partidos', () async {
      sportsApiBaseUrl.value = 'https://worker.example';
      SportsApiService.clientOverride = MockClient((request) async {
        return http.Response('', 204);
      });
      expect(await SportsApiService().checkFootballFixtures(), 0);
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
  });
}
