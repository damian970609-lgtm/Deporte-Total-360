import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sports_statistics_screen.dart';

void main() {
  testWidgets('estadísticas muestra selector multideporte e IDs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SportsStatisticsScreen()),
    );

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

  testWidgets('muestra las pestañas inferiores de Fantasy, Chat y Resúmenes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.text('Mister Fantasy'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Resúmenes'), findsOneWidget);
    expect(find.text('Estadísticas'), findsWidgets);
  });


}
