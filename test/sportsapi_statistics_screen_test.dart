import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sportsapi_app_service.dart';
import 'package:deporte_total_360/sportsapi_statistics_screen.dart';
import 'package:deporte_total_360/automatic_live_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FavoritesOnlyApi extends SportsApiAppService {
  _FavoritesOnlyApi(http.Client client) : super(client: client);

  @override
  Future<SportsAgendaWindow> fetchFavoriteAgendaWindow({
    DateTime? startDate,
    int days = 7,
    bool forceRefresh = false,
    void Function(SportsAgendaWindow window)? onProgress,
  }) async {
    throw const SportsApiException('Calendario temporalmente no disponible.');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFavoriteSports({
    bool forceRefresh = false,
  }) async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'football',
        'name': 'Fútbol',
        'competitions': <String>['Premier League'],
      },
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
        if (request.url.path.endsWith('/leagues/39/standings')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'rank': 1,
                  'team': {'name': 'Alpha FC'},
                  'points': 10,
                },
              ],
              'meta': {},
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

        // Comprueba controles de cabecera antes de desplazarse por la lista,
        // porque ListView construye de forma diferida los elementos fuera de vista.
        expect(find.byKey(const ValueKey<String>('stats-date-picker')), findsOneWidget);
        expect(find.text('TABLAS DE POSICIONES · TUS COMPETICIONES'), findsOneWidget);
        expect(
          requestedPaths,
          contains('/api/sportsapi/leagues/39/standings'),
        );
        expect(find.text('Alpha FC'), findsWidgets);

        final eventsHeading = find.text('EVENTOS DEL DÍA');
        await tester.scrollUntilVisible(
          eventsHeading,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(eventsHeading, findsOneWidget);
        final firstEvent = find.text('Alpha FC vs Beta FC');
        await tester.scrollUntilVisible(
          firstEvent,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(firstEvent, findsOneWidget);
        expect(find.text('Fútbol'), findsWidgets);
        expect(find.text('Baloncesto'), findsNothing);

        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Beta');
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Alpha FC vs Beta FC'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Alpha FC vs Beta FC'), findsOneWidget);

        await tester.ensureVisible(find.byKey(const ValueKey<String>('stats-filter-live')));
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
        // La cabecera quedó fuera del viewport y ListView descartó sus widgets.
        // Vuelve al inicio por posición para reconstruir la fecha antes de tocarla.
        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        scrollable.position.jumpTo(scrollable.position.minScrollExtent);
        await tester.pumpAndSettle();
        expect(nextDateButton, findsOneWidget);
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

  testWidgets(
    'muestra deportes y ligas favoritas aunque falle la carga del calendario',
    (tester) async {
      final client = MockClient((request) async => http.Response('{}', 404));
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: SportsApiStatisticsScreen(api: _FavoritesOnlyApi(client)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fútbol'), findsOneWidget);
        expect(find.text('Baloncesto'), findsNothing);
        expect(
          find.text('1 competiciones configuradas para Fútbol'),
          findsOneWidget,
        );
        await tester.tap(find.text('COMPETICIONES FAVORITAS'));
        await tester.pumpAndSettle();
        expect(find.text('Premier League'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.close();
      }
    },
  );

  testWidgets(
    'muestra juntos los eventos de todos los deportes favoritos y permite filtrar por deporte',
    (tester) async {
      final previousBase = sportsApiBaseUrl.value;
      sportsApiBaseUrl.value = 'https://worker-statistics-all-favorites.example';
      final now = DateTime.now();
      final localMidday = DateTime(now.year, now.month, now.day, 12);
      final eventStart = localMidday.toUtc().toIso8601String();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/favorites')) {
          return http.Response(jsonEncode({
            'sports': [
              {'id': 'football', 'name': 'Fútbol', 'competitions': ['Premier League']},
              {'id': 'basketball', 'name': 'Baloncesto', 'competitions': ['NBA']},
            ],
          }), 200);
        }
        if (request.url.path.endsWith('/fixtures')) {
          final sport = request.url.queryParameters['sport'];
          final row = sport == 'basketball'
              ? {
                  'id': 202,
                  'startTime': eventStart,
                  'home': {'name': 'Basket Club'},
                  'away': {'name': 'Rival Basket'},
                  'league': {'id': 12, 'name': 'NBA'},
                  'season': {'id': 2026},
                  'status': {'type': 'scheduled'},
                }
              : {
                  'id': 101,
                  'startTime': eventStart,
                  'home': {'name': 'Alpha FC'},
                  'away': {'name': 'Beta FC'},
                  'league': {'id': 39, 'name': 'Premier League'},
                  'season': {'id': 2026},
                  'status': {'type': 'scheduled'},
                };
          return http.Response(jsonEncode({
            'data': [row],
            'meta': {'complete': true, 'hasNextPage': false},
          }), 200);
        }
        if (request.url.path.endsWith('/races')) {
          return http.Response(jsonEncode({'data': [], 'meta': {'complete': true}}), 200);
        }
        return http.Response(jsonEncode({'data': {}, 'meta': {}}), 200);
      });

      try {
        await tester.pumpWidget(MaterialApp(
          home: SportsApiStatisticsScreen(api: SportsApiAppService(client: client)),
        ));
        await tester.pumpAndSettle();

        final alphaEvent = find.text('Alpha FC vs Beta FC');
        await tester.scrollUntilVisible(
          alphaEvent,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(alphaEvent, findsOneWidget);
        final basketEvent = find.text('Basket Club vs Rival Basket');
        await tester.scrollUntilVisible(
          basketEvent,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(basketEvent, findsOneWidget);
        expect(find.byKey(const ValueKey<String>('stats-filter-sport-all')), findsOneWidget);

        final basketballChip = find.widgetWithText(ChoiceChip, 'Baloncesto');
        await tester.tap(basketballChip);
        await tester.pumpAndSettle();
        expect(find.text('Basket Club vs Rival Basket'), findsOneWidget);
        expect(find.text('Alpha FC vs Beta FC'), findsNothing);

        await tester.tap(find.byKey(const ValueKey<String>('stats-filter-sport-all')));
        await tester.pumpAndSettle();
        expect(find.text('Alpha FC vs Beta FC'), findsOneWidget);
        expect(find.text('Basket Club vs Rival Basket'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        sportsApiBaseUrl.value = previousBase;
        client.close();
      }
    },
  );


  testWidgets(
    'recupera eventos guardados en el teléfono cuando el Worker no responde',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final savedEvent = SportsAgendaEvent(
        id: 'sportsapi-fixture-offline-101',
        title: 'Alpha FC vs Beta FC',
        sport: 'Fútbol',
        competition: 'Premier League',
        homeTeam: 'Alpha FC',
        awayTeam: 'Beta FC',
        startsAt: today.add(const Duration(hours: 18)),
        detailUrl: 'https://deporte-total-360-api.example/api/sportsapi/fixtures/101',
      );
      await SportsAgendaStore.saveWindow(
        <SportsAgendaEvent>[savedEvent],
        startDate: today,
        days: 1,
      );

      final client = MockClient((request) async => http.Response('{}', 503));
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: SportsApiStatisticsScreen(api: _FavoritesOnlyApi(client)),
          ),
        );
        await tester.pumpAndSettle();

        final offlineEvent = find.text('Alpha FC vs Beta FC');
        await tester.scrollUntilVisible(
          offlineEvent,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(offlineEvent, findsOneWidget);
        expect(
          find.textContaining('últimos eventos guardados en este teléfono'),
          findsOneWidget,
        );
        expect(find.text('No se pudo cargar la agenda'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.close();
      }
    },
  );

}
