import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/channel_catalog_screen.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void _noopHomeNavigate(int _) {}
void _noopHomeAction() {}

class _AdminTestService extends ChannelCatalogService {
  _AdminTestService({this.autoSignIn = true});

  final bool autoSignIn;
  final List<String> deletedSourceIds = <String>[];

  @override
  Future<String?> restoreSession() async =>
      autoSignIn ? 'admin@example.com' : null;

  @override
  Future<ChannelCatalogPage> fetchAdminChannelPage({
    String search = '',
    int offset = 0,
  }) async {
    return const ChannelCatalogPage(
      channels: <SportsChannel>[],
      total: 0,
      offset: 0,
      hasMore: false,
    );
  }

  @override
  Future<List<ChannelPlaylistSource>> fetchSources() async {
    return const <ChannelPlaylistSource>[
      ChannelPlaylistSource(
        id: 'source-imported',
        url: 'https://lists.example/imported.m3u',
        label: 'Lista importada',
        status: 'imported',
        importedCount: 4,
        lastImportedAt: '2026-11-06T12:00:00Z',
      ),
      ChannelPlaylistSource(
        id: 'source-queued',
        url: 'https://lists.example/queued.m3u',
        label: 'Lista en cola',
        status: 'queued',
      ),
    ];
  }

  @override
  Future<List<AppLicenseRecord>> fetchAdminLicenses() async =>
      <AppLicenseRecord>[];

  @override
  Future<Map<String, dynamic>> addPlaylistSourcesToCatalog({
    required List<Map<String, String>> sources,
  }) async => <String, dynamic>{
        'added': sources.length,
        'duplicates': 0,
        'total': 100,
        'limit': 100,
        'complete': true,
      };

  @override
  Future<void> deletePlaylistSource({required String id}) async {
    deletedSourceIds.add(id);
  }
}

void main() {
  testWidgets('la agenda de fútbol muestra por defecto los próximos siete días', (tester) async {
    sportsApiBaseUrl.value = '';
    await tester.pumpWidget(
      const MaterialApp(home: AgendaScreen(initialSport: 'Fútbol')),
    );

    expect(find.text('Próximos 7 días'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
  });

  testWidgets('DAMIAN.APK abre el panel secreto después de diez pulsaciones', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: false);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(adminService: service)),
    );
    await tester.pump();

    final signature = find.text('DAMIAN.APK');
    expect(signature, findsOneWidget);
    for (var tap = 0; tap < 9; tap++) {
      await tester.tap(signature);
      await tester.pump();
    }
    expect(find.text('ADMINISTRACIÓN · DAMIÁN.APK'), findsNothing);

    await tester.tap(signature);
    await tester.pumpAndSettle();
    expect(find.text('ADMINISTRACIÓN · DAMIÁN.APK'), findsOneWidget);
    expect(find.text('ENTRAR CON GOOGLE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel privado exige autenticación antes de mostrar las listas', (tester) async {
    final service = _AdminTestService(autoSignIn: false);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PANEL PRIVADO DE CANALES'), findsOneWidget);
    expect(find.text('ENTRAR CON GOOGLE'), findsOneWidget);
    expect(find.text('CATÁLOGO DE FUENTES · 100 LISTAS'), findsNothing);
    expect(service.deletedSourceIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
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
          onTelegram: () {},
          onContact: () {},
          onDonations: () {},
          onFantasy: () {},
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
          onTelegram: _noopHomeAction,
          onContact: _noopHomeAction,
          onDonations: _noopHomeAction,
          onFantasy: _noopHomeAction,
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

  testWidgets('las flechas de navegación nunca cubren etiquetas antes ni después de desplazar', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    void expectNoNavigationLabelBehindCues() {
      final viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('bottom-nav-scroll-viewport')),
      );
      final labels = List<Finder>.generate(
        8,
        (index) => find.byKey(ValueKey<String>('bottom-tab-label-$index')),
      );
      final cues = <Finder>[
        find.byKey(const ValueKey<String>('bottom-nav-scroll-left')),
        find.byKey(const ValueKey<String>('bottom-nav-scroll-right')),
      ].where((finder) => finder.evaluate().isNotEmpty);

      for (final cue in cues) {
        final cueRect = tester.getRect(cue);
        for (var index = 0; index < labels.length; index++) {
          final visibleLabelRect = tester.getRect(labels[index]).intersect(viewportRect);
          if (visibleLabelRect.isEmpty) continue;
          expect(
            cueRect.overlaps(visibleLabelRect),
            isFalse,
            reason: 'La flecha no debe cubrir la parte visible de la etiqueta de la pestaña $index.',
          );
        }
      }
    }

    expect(find.byKey(const ValueKey<String>('bottom-nav-scroll-right')), findsOneWidget);
    expectNoNavigationLabelBehindCues();

    await tester.tap(find.byKey(const ValueKey<String>('bottom-nav-scroll-right')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey<String>('bottom-nav-scroll-left')), findsOneWidget);
    expectNoNavigationLabelBehindCues();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inicio se estabiliza cuando Android solicita reducir movimiento', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: HomeDashboard(
            onNavigate: (_) {},
            onTelegram: () {},
            onContact: () {},
            onDonations: () {},
            onFantasy: () {},
            onOpenAgenda: () {},
            onChat: () {},
          ),
        ),
      ),
    );

    // Con el movimiento reducido no debe quedar un ticker infinito activo.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inicio conserva el contenido con texto ampliado al 200 por ciento', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: HomeDashboard(
            onNavigate: (_) {},
            onTelegram: () {},
            onContact: () {},
            onDonations: () {},
            onFantasy: () {},
            onOpenAgenda: () {},
            onChat: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(find.text('TODO EL DEPORTE'), findsOneWidget);
    expect(find.text('EN UN SOLO LUGAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('muestra las ocho secciones principales y presenta Chat, Actualización y Ajustes', (tester) async {
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
    expect(find.text('Mister Fantasy'), findsOneWidget);
    expect(find.text('Estadísticas'), findsNothing);
    expect(find.text('Resúmenes'), findsNothing);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Actualización'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    // La sala pública no arranca hasta seleccionar su pestaña.
    expect(find.text('CHAT DE COMPRADORES'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la navegación inferior permite recorrer las ocho secciones', (tester) async {
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
    expect(find.text('CHAT DE COMPRADORES'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
