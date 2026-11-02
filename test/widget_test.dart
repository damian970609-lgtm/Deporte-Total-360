import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/news_screen.dart';
import 'package:deporte_total_360/web_agenda_screen.dart';
import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sports_statistics_screen.dart';

void main() {
  setUp(() {
    SportsApiService.clientOverride = MockClient((request) async {
      if (request.url.path.endsWith('/leagues')) {
        return http.Response(jsonEncode(<String, dynamic>{
          'response': <Map<String, dynamic>>[
            <String, dynamic>{
              'league': <String, dynamic>{'id': 39, 'name': 'Premier League'},
              'country': <String, dynamic>{'name': 'England'},
              'seasons': <Map<String, dynamic>>[
                <String, dynamic>{'year': DateTime.now().year, 'current': true},
              ],
            },
          ],
          'errors': <String, dynamic>{},
        }), 200);
      }
      return http.Response(jsonEncode(<String, dynamic>{
        'response': <dynamic>[],
        'errors': <String, dynamic>{},
      }), 200);
    });
  });

  tearDown(() {
    SportsApiService.clientOverride = null;
    SportsApiService.resetForTesting();
  });

  testWidgets('estadísticas muestra selector multideporte e IDs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SportsStatisticsScreen()),
    );
    await tester.pump();

    expect(find.text('ESTADÍSTICAS DEPORTIVAS'), findsOneWidget);
    expect(find.text('BUSCAR LIGAS'), findsOneWidget);
    expect(find.text('SPORT ID  •  football'), findsOneWidget);
    expect(find.textContaining('Fútbol'), findsOneWidget);
  });

  testWidgets('ofrece la categoría Fórmula 1 y abre su pantalla específica', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsStatisticsScreen(initialSport: 'Fórmula 1'),
      ),
    );
    await tester.pump();

    expect(find.text('SPORT ID  •  formula-1'), findsOneWidget);
    expect(find.textContaining('Tipo de clasificación'), findsOneWidget);
  });
  testWidgets('la agenda de fútbol muestra por defecto los próximos siete días', (tester) async {
    sportsApiBaseUrl.value = '';
    await tester.pumpWidget(
      const MaterialApp(home: AgendaScreen(initialSport: 'Fútbol')),
    );

    expect(find.text('Próximos 7 días'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
  });

  testWidgets('Ajustes expone un acceso visible al servidor deportivo', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen()),
    );
    await tester.pump();

    expect(find.text('Servidor de estadísticas y agenda'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('Inicio aparece antes de crear pantallas de red', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(find.text('TODOS LOS DEPORTES'), findsOneWidget);
    expect(find.byType(NewsScreen), findsNothing);
    expect(find.byType(WebAgendaScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inicio conserva accesos y Explorar abre Estadísticas', (tester) async {
    var statisticsOpened = 0;
    var wrongTabSelected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDashboard(
          onNavigate: (index) => wrongTabSelected = index,
          onSportSelected: (_) {},
          onTelegram: () {},
          onContact: () {},
          onDonations: () {},
          onFantasy: () {},
          onStatistics: () => statisticsOpened++,
          onOpenAgenda: () {},
          onChat: () {},
        ),
      ),
    );

    expect(find.text('TODOS LOS DEPORTES'), findsOneWidget);
    expect(find.text('TRANSMISIONES EN VIVO'), findsOneWidget);
    expect(find.text('AGENDA DE PARTIDOS'), findsOneWidget);
    expect(find.text('TELEGRAM'), findsOneWidget);
    expect(find.text('FACEBOOK'), findsNothing);
    expect(find.text('FANTASY'), findsOneWidget);

    await tester.tap(find.text('Explorar →'));
    expect(statisticsOpened, 1);
    expect(wrongTabSelected, -1);
  });


  testWidgets('las pestañas inferiores siguen visibles al cambiar de sección', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(find.text('Fútbol Libre'), findsOneWidget);
    expect(find.text('Partidos'), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Canales TV'), findsOneWidget);

    await tester.tap(find.text('Partidos'));
    await tester.pump();

    expect(find.byType(AgendaScreen), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.text('Canales TV'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pump();
    expect(find.text('TODOS LOS DEPORTES'), findsOneWidget);
  });

}
