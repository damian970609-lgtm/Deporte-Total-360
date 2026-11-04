import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/iptv_sources_screen.dart';
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

  testWidgets('el menú oculto DAMIAN.APK abre directamente el destino secreto', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          secretMenuBuilder: (_) => Scaffold(
            appBar: AppBar(title: const Text('REPRODUCTOR IPTV · LISTAS Y CANALES')),
            body: const Text('ÚNICO ACCESO DEL MENÚ SECRETO'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Servidor de estadísticas'), findsNothing);
    expect(find.text('DAMIAN.APK'), findsOneWidget);
    for (var tap = 0; tap < 10; tap++) {
      await tester.tap(find.text('DAMIAN.APK'));
    }
    await tester.pumpAndSettle();

    expect(find.text('REPRODUCTOR IPTV · LISTAS Y CANALES'), findsOneWidget);
    expect(find.text('ÚNICO ACCESO DEL MENÚ SECRETO'), findsOneWidget);
    expect(find.text('ABRIR REPRODUCTOR Y EXTRACTOR IPTV'), findsNothing);
    expect(find.text('CODOPLAYER · REPRODUCTOR WEB'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú secreto abre el reproductor IPTV integrado sin listas precargadas', (tester) async {
    Widget? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            destination = const DeveloperSettingsScreen().build(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(destination, isA<IptvSourcesScreen>());
    expect((destination as IptvSourcesScreen).manualOnly, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('el reproductor secreto empieza vacío y permite agregar listas manualmente', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MaterialApp(home: IptvSourcesScreen(manualOnly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('IMPORTAR TUS LISTAS M3U'), findsOneWidget);
    expect(find.text('AGREGAR LISTA M3U'), findsOneWidget);
    expect(find.text('AGREGAR GUÍA EPG'), findsOneWidget);
    expect(find.text('CARGAR MIS LISTAS Y CANALES'), findsOneWidget);
    expect(find.textContaining('ninguna lista pública automáticamente'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el reproductor IPTV permite guardar favoritos y buscar canales', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_texts_v1': <String>[
        '#EXTM3U\n#EXTINF:-1 group-title="Deportes",Prueba TV\nhttps://media.example/prueba.m3u8',
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(home: IptvSourcesScreen(manualOnly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prueba TV'), findsOneWidget);
    expect(find.byTooltip('Agregar a favoritos'), findsOneWidget);
    expect(find.byTooltip('Copiar URL del canal'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba TV agregado a favoritos.'), findsOneWidget);
    expect(find.text('FAVORITOS (1)'), findsOneWidget);

    await tester.tap(find.text('FAVORITOS (1)'));
    await tester.pumpAndSettle();
    expect(find.text('MIS CANALES FAVORITOS (1)'), findsOneWidget);
    expect(find.text('Prueba TV'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'canal inexistente');
    await tester.pumpAndSettle();
    expect(find.text('MIS CANALES FAVORITOS (0)'), findsOneWidget);
    expect(find.textContaining('Todavía no tienes favoritos'), findsOneWidget);

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

  testWidgets('muestra las ocho secciones principales y deja Chat como acceso auxiliar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.text('Deportes en vivo'), findsOneWidget);
    expect(find.text('Agenda de hoy'), findsOneWidget);
    expect(find.text('Noticias'), findsWidgets);
    expect(find.text('Mister Fantasy'), findsOneWidget);
    expect(find.text('Estadísticas'), findsWidgets);
    expect(find.text('Resúmenes'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('CHAT PÚBLICO'), findsOneWidget);
  });


}
