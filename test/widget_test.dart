import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sports_statistics_screen.dart';

void _noopHomeNavigate(int _) {}
void _noopHomeSport(String _) {}
void _noopHomeAction() {}

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

    expect(find.text('Servidor de estadísticas'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('Inicio muestra el emblema 3D sin accesos directos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDashboard(
          onNavigate: (_) {},
          onSportSelected: (_) {},
          onTelegram: () {},
          onContact: () {},
          onDonations: () {},
          onFantasy: () {},
          onStatistics: () {},
          onOpenAgenda: () {},
          onChat: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(find.text('DEPORTE TOTAL 360°'), findsOneWidget);
    expect(find.text('ACCESO RÁPIDO'), findsNothing);
    expect(find.text('TRANSMISIONES EN VIVO'), findsNothing);
    expect(find.text('AGENDA DE PARTIDOS'), findsNothing);
    expect(find.text('TELEGRAM'), findsNothing);
    expect(find.text('FANTASY'), findsNothing);
    expect(find.text('Explorar →'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inicio se adapta a móvil compacto y tableta', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeDashboard(
          onNavigate: _noopHomeNavigate,
          onSportSelected: _noopHomeSport,
          onTelegram: _noopHomeAction,
          onContact: _noopHomeAction,
          onDonations: _noopHomeAction,
          onFantasy: _noopHomeAction,
          onStatistics: _noopHomeAction,
          onOpenAgenda: _noopHomeAction,
          onChat: _noopHomeAction,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Una pantalla ancha y baja debe reducir el emblema sin crear overflow.
    tester.view.physicalSize = const Size(915, 412);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('muestra las diez secciones principales y presenta Chat antes de Ajustes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    // Pintar un segundo frame comprueba el render inicial de Inicio, no solo
    // que el árbol de widgets se pueda construir.
    await tester.pump();
    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.text('Deportes en vivo'), findsOneWidget);
    expect(find.text('Canales deportivos'), findsOneWidget);
    // La pantalla de transmisiones no debe arrancar ni consultar servicios
    // hasta que el usuario entre en esa pestaña.
    expect(find.text('TRANSMISIONES EN VIVO'), findsNothing);
    expect(find.text('Agenda de hoy'), findsOneWidget);
    expect(find.text('Noticias'), findsWidgets);
    expect(find.text('Mister Fantasy'), findsOneWidget);
    expect(find.text('Estadísticas'), findsWidgets);
    expect(find.text('Resúmenes'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    // La sala pública no arranca hasta seleccionar su pestaña.
    expect(find.text('CHAT PÚBLICO'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la navegación inferior permite recorrer las diez secciones', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final forward = find.byKey(const ValueKey<String>('bottom-nav-scroll-right'));
    expect(forward, findsOneWidget);
    await tester.tap(forward);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(
      find.byKey(const ValueKey<String>('bottom-nav-scroll-left')),
      findsOneWidget,
    );
    expect(find.text('Ajustes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Chat abre dentro de la navegación principal', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    final chatTab = find.text('Chat');
    await tester.ensureVisible(chatTab);
    await tester.tap(chatTab);
    await tester.pump();
    expect(find.text('CHAT PÚBLICO'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
