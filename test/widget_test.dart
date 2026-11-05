import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/iptv_sources_screen.dart';
import 'package:deporte_total_360/iptv_player_screen.dart';
import 'package:deporte_total_360/sports_api_service.dart';
import 'package:deporte_total_360/sports_statistics_screen.dart';

void main() {
  test('el formulario manual conserva URLs completas al separar varias listas', () {
    const firstUrl = 'https://raw.githubusercontent.com/iptv/listas/deportes.m3u';
    const secondUrl = 'https://cdn.example.net/canales/directos.m3u8';

    expect(
      parseManualSourceUrls('$firstUrl\r\n$secondUrl; $firstUrl'),
      equals(<String>[firstUrl, secondUrl]),
    );
  });

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

  testWidgets('la ruta real de DAMIAN.APK abre y carga el reproductor integrado', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,
    });
    const playlist = '#EXTM3U\\n'
        '#EXTINF:-1 group-title="Deportes",Canal del menú secreto\\n'
        'https://media.example/secret.m3u8';
    final client = MockClient((request) async => http.Response(playlist, 200));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          secretMenuBuilder: (_) => IntegratedIptvPlayerScreen(
            parseInBackground: false,
            httpClient: client,
          ),
        ),
      ),
    );
    await tester.pump();

    for (var tap = 0; tap < 10; tap++) {
      await tester.tap(find.text('DAMIAN.APK'));
    }
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.text('AÑADIR LISTAS'), findsOneWidget);
    expect(find.text('CARGAR ARCHIVOS'), findsOneWidget);
    expect(find.text('Canal del menú secreto'), findsOneWidget);
    expect(find.text('No se pudo mostrar esta sección'), findsNothing);

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
    expect(destination, isA<IntegratedIptvPlayerScreen>());
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('el reproductor limpia listas antiguas y conserva solo la fuente automática', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_urls_v1': <String>[
        'https://old.example/uno.m3u',
        'https://old.example/dos.m3u',
      ],
      'dt360_secret_iptv_playlist_texts_v1': <String>['#EXTM3U antigua'],
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('dt360_secret_iptv_playlist_urls_v1'),
      <String>[defaultSecretIptvSportsPlaylistUrl],
    );
    expect(prefs.getStringList('dt360_secret_iptv_playlist_texts_v1'), isNull);
    expect(prefs.getBool('dt360_secret_iptv_playlist_cleanup_v1'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el reproductor integrado empieza vacío y permite añadir varias listas', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,});
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.text('AÑADIR LISTAS'), findsOneWidget);
    expect(find.text('CARGAR ARCHIVOS'), findsOneWidget);
    expect(find.text('IMPORTAR PEGADA'), findsOneWidget);
    expect(find.text('PEGAR LISTA M3U'), findsOneWidget);
    expect(find.text('TU REPRODUCTOR ESTÁ LISTO'), findsOneWidget);

    await tester.tap(find.text('AÑADIR LISTAS'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar listas M3U / M3U8'), findsOneWidget);
    expect(find.text('URLs de tus listas (una por línea)'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no pierde una URL agregada durante la carga inicial', (tester) async {
    const sportsPlaylist = '#EXTM3U\\n'
        '#EXTINF:-1 group-title="Deportes",Canal Deportivo\\n'
        'https://media.example/sports.m3u8';
    const personalPlaylist = '#EXTM3U\\n'
        '#EXTINF:-1 group-title="Deportes",Canal Personal\\n'
        'https://media.example/personal.m3u8';

    final initialResponse = Completer<http.Response>();
    final initialRequestStarted = Completer<void>();
    var sportsRequests = 0;
    var personalRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'iptv-org.github.io') {
        sportsRequests++;
        if (sportsRequests == 1) {
          if (!initialRequestStarted.isCompleted) {
            initialRequestStarted.complete();
          }
          return initialResponse.future;
        }
        return http.Response(sportsPlaylist, 200);
      }
      if (request.url.host == 'personal.example') {
        personalRequests++;
        return http.Response(personalPlaylist, 200);
      }
      return http.Response('', 404);
    });

    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,
      'dt360_secret_iptv_playlist_urls_v1': <String>[
        defaultSecretIptvSportsPlaylistUrl,
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: IntegratedIptvPlayerScreen(
          parseInBackground: false,
          httpClient: client,
        ),
      ),
    );
    await tester.runAsync(() => initialRequestStarted.future);
    await tester.pump();

    await tester.tap(find.text('AÑADIR LISTAS'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'https://personal.example/my-list.m3u',
    );
    await tester.tap(find.text('AGREGAR'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('dt360_secret_iptv_playlist_urls_v1'),
      contains('https://personal.example/my-list.m3u'),
    );

    initialResponse.complete(http.Response(sportsPlaylist, 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    expect(sportsRequests, 2);
    expect(personalRequests, 1);
    expect(find.text('Canal Personal'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el reproductor integrado importa una M3U y muestra su canal', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,});
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PEGAR LISTA M3U'));
    await tester.pumpAndSettle();
    const playlist = '#EXTM3U\n'
        '#EXTINF:-1 group-title="Deportes",Canal Importado\n'
        'https://media.example/live/98765?token=abc';
    await tester.enterText(find.byType(TextField).last, playlist);
    await tester.tap(find.text('IMPORTAR'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canal Importado'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('dt360_secret_iptv_playlist_texts_v1'),
      contains(playlist),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el reproductor integra varias listas y agrupa canales duplicados', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,
      'dt360_secret_iptv_playlist_texts_v1': <String>[
        '#EXTM3U\n#EXTINF:-1 tvg-id="sports.es" group-title="Deportes",Canal Deportes\nhttps://media.example/live/uno.m3u8',
        '#EXTM3U\n#EXTINF:-1 tvg-id="sports.es" group-title="Deportes",Canal Deportes HD\nhttps://media.example/live/dos.m3u8',
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canal Deportes'), findsOneWidget);
    expect(find.text('Canal Deportes HD'), findsNothing);
    expect(find.textContaining('2 fuentes disponibles'), findsOneWidget);
    expect(find.byTooltip('Copiar identificador DT360'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el reproductor integrado permite favoritos, búsqueda y copia de URL', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_cleanup_v1': true,
      'dt360_secret_iptv_playlist_texts_v1': <String>[
        '#EXTM3U\n#EXTINF:-1 group-title="Deportes",Prueba TV\nhttps://media.example/prueba.m3u8',
      ],
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prueba TV'), findsOneWidget);
    expect(find.byTooltip('Agregar a favoritos'), findsOneWidget);
    expect(find.byTooltip('Copiar URL del canal'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('FAVORITOS (1)'), findsOneWidget);
    final savedFavorites = await SharedPreferences.getInstance();
    expect(
      savedFavorites.getStringList('dt360_secret_iptv_favorite_urls_v1'),
      contains('https://media.example/prueba.m3u8'),
    );

    await tester.tap(find.text('FAVORITOS (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba TV'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'canal inexistente');
    await tester.pumpAndSettle();
    expect(
      find.text('No tienes favoritos que coincidan con la búsqueda.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: IntegratedIptvPlayerScreen(parseInBackground: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('FAVORITOS (1)'), findsOneWidget);
    await tester.tap(find.text('FAVORITOS (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba TV'), findsOneWidget);

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
