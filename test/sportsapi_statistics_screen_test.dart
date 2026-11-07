import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sportsapi_app_service.dart';
import 'package:deporte_total_360/sportsapi_statistics_screen.dart';

void main() {
  testWidgets(
    'Estadísticas permite buscar, filtrar, comparar datos y navegar entre fechas locales',
    (tester) async {
      final previousBase = sportsApiBaseUrl.value;
      sportsApiBaseUrl.value = 'https://worker-statistics-screen.example';

      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day, 12, 30);
      final startTime = localStart.toUtc().toIso8601String();
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/favorites')) {
          return http.Response(
            jsonEncode({
              'sports': [
                {
                  'id': 'football',
                  'name': 'Fútbol',
                  'enabled': true,
                  'competitions': ['Premier League'],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/fixtures')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 101,
                  'startTime': startTime,
                  'home': {'name': 'Alpha FC'},
                  'away': {'name': 'Beta FC'},
                  'league': {'id': 39, 'name': 'Premier League'},
                  'season': {'id': 2026, 'name': '2026'},
                  'status': {'type': 'live', 'description': 'En juego'},
                  'homeScore': 2,
                  'awayScore': 1,
                },
              ],
              'meta': {'complete': true, 'hasNextPage': false},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/fixtures/101/statistics')) {
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
                          {
                            'name': 'Posesión',
                            'home': {'display': '55%'},
                            'away': {'display': '45%'},
                          },
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
        }
        return http.Response(
          jsonEncode({'error': {'message': 'Ruta no esperada'}}),
          404,
        );
      });

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: SportsApiStatisticsScreen(
              api: SportsApiAppService(client: client),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('EVENTOS DEL DÍA'), findsOneWidget);
        expect(find.text('Alpha FC vs Beta FC'), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('stats-date-picker')), findsOneWidget);

        final search = find.byType(TextField);
        await tester.enterText(search, 'Beta');
        await tester.pump();
        expect(find.text('Alpha FC vs Beta FC'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey<String>('stats-filter-live')));
        await tester.pump();
        expect(find.text('Alpha FC vs Beta FC'), findsOneWidget);

        final event = find.text('Alpha FC vs Beta FC');
        await tester.ensureVisible(event);
        await tester.tap(event);
        await tester.pumpAndSettle();

        expect(find.text('ESTADÍSTICAS · Premier League'), findsOneWidget);
        expect(find.text('Posesión'), findsOneWidget);
        expect(find.text('LOCAL'), findsOneWidget);
        expect(find.text('VISITANTE'), findsOneWidget);
        expect(find.text('55%'), findsOneWidget);
        expect(find.text('45%'), findsOneWidget);
        expect(
          requestedPaths,
          contains('/api/sportsapi/fixtures/101/statistics'),
        );

        final nextDateButton =
            find.byKey(const ValueKey<String>('stats-date-next'));
        await tester.ensureVisible(nextDateButton);
        await tester.tap(nextDateButton);
        await tester.pumpAndSettle();

        expect(find.textContaining('MAÑANA'), findsWidgets);
        expect(find.text('Alpha FC vs Beta FC'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        sportsApiBaseUrl.value = previousBase;
        client.close();
      }
    },
  );
}
