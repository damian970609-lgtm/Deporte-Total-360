import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/live_channels_screen.dart';
import 'package:deporte_total_360/channel_catalog_screen.dart';
import 'package:deporte_total_360/agenda_channels_screen.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/channel_playlist_presets.dart';

void _noopHomeNavigate(int _) {}
void _noopHomeAction() {}

class _AdminTestService extends ChannelCatalogService {
  _AdminTestService({
    this.autoSignIn = true,
    this.adminTotal = 2,
    this.sourceCount = 2,
    this.offline = false,
  }) : _storedSourceCount = sourceCount;

  final bool autoSignIn;
  final bool offline;
  final int adminTotal;
  final int sourceCount;
  int _storedSourceCount;
  int _adminPageCalls = 0;
  int lastAdminPageLimit = 0;
  final List<String> deletedSourceIds = <String>[];
  final List<Map<String, String>> addedPlaylistRequests =
      <Map<String, String>>[];
  bool refreshRequested = false;

  @override
  Future<String?> restoreSession() async =>
      autoSignIn ? 'admin@example.com' : null;

  @override
  Future<ChannelCatalogPage> fetchAdminChannelPage({
    String search = '',
    int offset = 0,
    int limit = 200,
  }) async {
    if (offline) {
      throw const ChannelCatalogException('Servidor sin conexión en la prueba.');
    }
    _adminPageCalls++;
    lastAdminPageLimit = limit;
    if (limit <= 200) {
      return ChannelCatalogPage(
        channels: <SportsChannel>[
          SportsChannel(
            id: 'sports-channel',
            identifier: 'sports-channel',
            name: 'ESPN Deportes',
            url: 'https://media.example/espn.m3u8',
            isSports: true,
            visible: false,
            language: 'es',
          ),
          SportsChannel(
            id: 'general-channel',
            identifier: 'general-channel',
            name: 'Canal General',
            url: 'https://media.example/general.m3u8',
            isSports: false,
            visible: false,
          ),
        ],
        total: adminTotal,
        offset: 0,
        hasMore: adminTotal > 2,
        totalIsEstimate: adminTotal > 2,
      );
    }
    final end = (offset + limit).clamp(0, adminTotal).toInt();
    final channels = <SportsChannel>[];
    for (var index = offset; index < end; index++) {
      if (index == 0) {
        channels.add(const SportsChannel(id: 'sports-channel', identifier: 'sports-channel', name: 'ESPN Deportes', url: 'https://media.example/espn.m3u8', isSports: true, visible: false, language: 'es'));
      } else if (index == 1) {
        channels.add(const SportsChannel(id: 'general-channel', identifier: 'general-channel', name: 'Canal General', url: 'https://media.example/general.m3u8', isSports: false, visible: false));
      } else {
        channels.add(SportsChannel(id: 'channel-$index', identifier: 'channel-$index', name: 'Canal $index', url: 'https://media.example/channel-$index.m3u8', isSports: index.isEven, visible: false));
      }
    }
    return ChannelCatalogPage(
      channels: channels,
      total: adminTotal,
      offset: offset,
      hasMore: end < adminTotal,
      totalIsEstimate: end < adminTotal,
    );
  }

  @override
  Future<List<ChannelPlaylistSource>> fetchSources() async {
    if (offline) {
      throw const ChannelCatalogException('Servidor sin conexión en la prueba.');
    }
    final existing = List<ChannelPlaylistSource>.generate(
      _storedSourceCount,
      (index) => ChannelPlaylistSource(
        id: 'source-$index',
        url: 'https://lists.example/source-$index.m3u',
        label: sourceCount == 2
            ? (index == 0 ? 'Lista importada' : 'Lista en cola')
            : 'Lista registrada ${(index + 1).toString().padLeft(3, '0')}',
        status: index == 0 ? 'imported' : 'queued',
        importedCount: index == 0 ? 4 : 0,
      ),
      growable: false,
    );
    final added = addedPlaylistRequests.map(
      (source) => ChannelPlaylistSource(
        id: 'source-added-${source['url']!.hashCode.abs()}',
        url: source['url']!,
        label: source['label']!,
        status: 'queued',
      ),
    );
    return <ChannelPlaylistSource>[...existing, ...added];
  }

  @override
  Future<List<AppLicenseRecord>> fetchAdminLicenses() async {
    if (offline) {
      throw const ChannelCatalogException('Servidor sin conexión en la prueba.');
    }
    return <AppLicenseRecord>[];
  }

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
  Future<Map<String, dynamic>> fetchTrialPassSummary() async {
    if (offline) {
      throw const ChannelCatalogException('Servidor sin conexión en la prueba.');
    }
    return <String, dynamic>{
      'available': 10,
      'active': 0,
      'expired': 0,
      'revoked': 0,
      'total': 10,
    };
  }

  @override
  Future<void> addPlaylist({
    required String url,
    required String label,
  }) async {
    if (!addedPlaylistRequests.any((item) => item['url'] == url)) {
      addedPlaylistRequests.add(<String, String>{
        'url': url,
        'label': label,
      });
    }
  }

  @override
  Future<void> refreshSources() async {
    refreshRequested = true;
  }

  @override
  Future<void> deletePlaylistSource({required String id}) async {
    deletedSourceIds.add(id);
  }
}

void main() {
  testWidgets('DAMIAN.APK queda como firma y no abre el antiguo panel IPTV', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    final signature = find.text('DAMIAN.APK');
    expect(signature, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('settings-damian-apk-menu')), findsNothing);
    for (var tap = 0; tap < 12; tap++) {
      await tester.tap(signature);
      await tester.pump();
    }

    expect(find.text('IPTV · DAMIÁN.APK', skipOffstage: false), findsNothing);
    expect(find.text('ENTRAR CON GOOGLE'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel pagina la copia local y no construye todos los canales al abrir', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final cachedChannels = List<SportsChannel>.generate(
      85,
      (index) => SportsChannel(
        id: 'cached-$index',
        identifier: 'cached-$index',
        name: 'Canal cacheado ${index.toString().padLeft(3, '0')}',
        url: 'https://media.example/cached-$index.m3u8',
        isSports: index.isEven,
        visible: false,
      ),
      growable: false,
    );
    final cachedSources = List<ChannelPlaylistSource>.generate(
      2,
      (index) => ChannelPlaylistSource(
        id: 'cached-source-$index',
        url: 'https://lists.example/cached-$index.m3u',
        label: 'Lista guardada $index',
        status: 'imported',
      ),
      growable: false,
    );
    final service = _AdminTestService(autoSignIn: true, offline: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ChannelAdminScreen(
          service: service,
          snapshotLoader: (email) async => ChannelAdminSnapshot(
            email: email,
            savedAt: DateTime(2026, 11, 12).toIso8601String(),
            channels: cachedChannels,
            sources: cachedSources,
            hasChannels: true,
            hasSources: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El contador está en la cabecera del ListView; compruébalo antes de
    // desplazarla fuera del árbol de widgets montados.
    expect(find.byKey(const ValueKey<String>('iptv-channel-total')), findsOneWidget);
    final firstCachedRow = find.byKey(
      const ValueKey<String>('iptv-channel-row-cached-0'),
    );
    await tester.scrollUntilVisible(
      firstCachedRow,
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('Canal cacheado 000'), findsOneWidget);
    expect(find.text('INVENTARIO COMPLETO DE CANALES'), findsNothing);
    expect(find.textContaining('CARGAR SIGUIENTE BLOQUE'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú Damián APK abre una sola vista IPTV con canales deportivos y generales juntos', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('IPTV · TODAS LAS LISTAS EN UNA SOLA'), findsOneWidget);
    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-general-channel')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('Canal General'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-sports-channel')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('ESPN Deportes'), findsOneWidget);
    expect(find.text('INVENTARIO COMPLETO DE CANALES'), findsNothing);
    expect(find.text('PROTECCIÓN Y RESTRICCIONES REGIONALES'), findsNothing);
    expect(find.text('PROTON VPN'), findsNothing);
    expect(find.text('2 CANALES'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel añade el índice global IPTV-org como fuente independiente', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    final addIndex = find.text('AÑADIR ÍNDICE GLOBAL IPTV-ORG');
    await tester.scrollUntilVisible(
      addIndex,
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    // Tras materializarse en el ListView, alinéalo dentro del área visible.
    await tester.ensureVisible(addIndex);
    await tester.pumpAndSettle();
    await tester.tap(addIndex);
    await tester.pumpAndSettle();

    expect(
      service.addedPlaylistRequests.any(
        (source) =>
            source['url'] == iptvOrgGlobalIndexPlaylistUrl &&
            source['label'] == iptvOrgGlobalIndexPlaylistLabel,
      ),
      isTrue,
    );
    // La adición de una fuente ya la pone en cola en Cloudflare.
    // No debe reimportar las 99 fuentes que ya estaban registradas.
    expect(service.refreshRequested, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel completa automáticamente la lista 120 con el índice GitHub cuando hay 119', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true, sourceCount: 119);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    expect(
      service.addedPlaylistRequests.any(
        (source) =>
            source['url'] == iptvOrgGlobalIndexPlaylistUrl &&
            source['label'] == iptvOrgGlobalIndexPlaylistLabel,
      ),
      isTrue,
    );
    expect(service.refreshRequested, isFalse);
    expect((await service.fetchSources()), hasLength(120));

    expect(find.text('IPTV · TODAS LAS LISTAS EN UNA SOLA'), findsOneWidget);
    expect(find.text('INVENTARIO COMPLETO DE CANALES'), findsNothing);
    expect(find.byKey(const ValueKey<String>('channel-admin-scroll')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('añadir una lista general no vuelve a importar las 99 fuentes existentes', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true, sourceCount: 118);
    // El índice global de GitHub ya forma parte de las 99 listas anteriores.
    service.addedPlaylistRequests.add(<String, String>{
      'url': iptvOrgGlobalIndexPlaylistUrl,
      'label': iptvOrgGlobalIndexPlaylistLabel,
    });
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    final addGeneral = find.text('AÑADIR LISTA GENERAL');
    await tester.scrollUntilVisible(
      addGeneral,
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await tester.ensureVisible(addGeneral);
    await tester.tap(addGeneral);
    await tester.pumpAndSettle();

    expect(service.addedPlaylistRequests, hasLength(2));
    expect(
      service.addedPlaylistRequests.any((source) =>
          source['url'] == channelPlaylistPresets.first.url),
      isTrue,
    );
    expect(service.refreshRequested, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú Damián APK no muestra Proton VPN ni el inventario administrativo antiguo', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.text('PROTON VPN'), findsNothing);
    expect(find.text('PROTON VPN · CONEXIÓN PROTEGIDA'), findsNothing);
    expect(find.text('ABRIR PROTON VPN'), findsNothing);
    expect(find.text('INVENTARIO COMPLETO DE CANALES'), findsNothing);
    expect(find.text('PROTECCIÓN Y RESTRICCIONES REGIONALES'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('IPTV permite actualizar todas las listas desde el catálogo unificado', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    // Primero lleva el botón a la zona visible. El catálogo usa una lista
    // desplazable y puede desmontar los controles que quedan fuera de pantalla.
    await tester.scrollUntilVisible(
      find.text('REIMPORTAR TODAS LAS LISTAS GUARDADAS'),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    final refresh = find.byTooltip('Actualizar todas las listas');
    expect(refresh, findsOneWidget);
    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(service.lastAdminPageLimit, channelAdminCatalogPageSize);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-general-channel')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('Canal General'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel privado exige autenticación antes de mostrar las listas', (tester) async {
    final service = _AdminTestService(autoSignIn: false);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PANEL PRIVADO DE CANALES'), findsOneWidget);
    expect(find.text('ENTRAR CON GOOGLE'), findsOneWidget);
    expect(find.text('CATÁLOGO DE FUENTES · 100 LISTAS'), findsNothing);
    expect(service.deletedSourceIds, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Ajustes ofrece actualización de APK y contacto directo por WhatsApp', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen()),
    );
    await tester.pump();

    expect(find.text('Servidor de datos deportivos'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('settings-update-apk')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Actualizar APK'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('creator-whatsapp-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('WHATSAPP DEL CREADOR'), findsOneWidget);
    expect(find.text('+592 721 4741'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('settings-update-apk')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('settings-update-apk')));
    // Espera a que termine la transición de MaterialPageRoute antes de
    // comprobar el contenido de la pantalla recién abierta.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('ACTUALIZAR APK'), findsOneWidget);
    expect(find.text('INSTALACIÓN SEGURA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('Inicio muestra el emblema 3D sin accesos directos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDashboard(
          onNavigate: (_) {},
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

  testWidgets('IPTV carga más de 200 canales en una sola lista y mantiene el formulario para añadir listas', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true, adminTotal: 2005);
    await tester.pumpWidget(MaterialApp(home: ChannelAdminScreen(service: service, snapshotLoader: (_) async => null)));
    await tester.pumpAndSettle();

    expect(
      service._adminPageCalls,
      greaterThan(0),
      reason: 'La sesión restaurada no solicitó ninguna página al servicio IPTV.',
    );
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('iptv-channel-total'))).data, '2005');
    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('channel-admin-iptv-list')), findsOneWidget);
    expect(find.text('AÑADIR CANALES Y LISTAS IPTV'), findsOneWidget);
    expect(service._adminPageCalls, greaterThanOrEqualTo(2));

    await tester.enterText(
      find.byKey(const ValueKey<String>('iptv-search-field')),
      'Canal General',
    );
    await tester.tap(find.byKey(const ValueKey<String>('iptv-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('Mostrando 1 de 2005 canales.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('iptv-search-clear')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('iptv-search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Mostrando 2005 de 2005 canales.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-general-channel')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.byKey(const ValueKey<String>('iptv-visibility-general-channel')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('iptv-language-general-channel')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-sports-channel')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.byKey(const ValueKey<String>('iptv-visibility-sports-channel')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('iptv-language-sports-channel')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reutiliza el catálogo IPTV completo guardado sin descargarlo otra vez', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _AdminTestService(autoSignIn: true);
    final cachedChannels = <SportsChannel>[
      const SportsChannel(
        id: 'cached-general',
        identifier: 'cached-general',
        name: 'Canal guardado general',
        url: '',
        isSports: false,
        visible: false,
      ),
      const SportsChannel(
        id: 'cached-sports',
        identifier: 'cached-sports',
        name: 'Canal deportivo guardado',
        url: 'https://media.example/cached.m3u8',
        isSports: true,
        visible: false,
        language: 'es',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChannelAdminScreen(
          service: service,
          snapshotLoader: (_) async => ChannelAdminSnapshot(
            email: 'admin@example.com',
            savedAt: '2026-11-16T00:00:00Z',
            channels: cachedChannels,
            sources: const <ChannelPlaylistSource>[],
            hasChannels: true,
            hasSources: true,
            channelsComplete: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service._adminPageCalls, 0);
    // El resumen forma parte de la primera tarjeta y se desmonta al desplazarse.
    expect(find.text('Mostrando 2 de 2 canales.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-cached-general')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('Canal guardado general'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-channel-row-cached-sports')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text('Canal deportivo guardado'), findsOneWidget);
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

  testWidgets('MainShell expone Inicio, Agenda, En vivo, Canales y Ajustes', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('home-sports-crest')), findsOneWidget);
    expect(find.text('DEPORTE TOTAL 360°'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('En vivo'), findsOneWidget);
    expect(find.text('Canales deportivos'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Agenda de hoy'), findsNothing);
    expect(find.text('Mister Fantasy'), findsNothing);
    expect(find.text('Chat'), findsNothing);
    expect(find.byKey(const ValueKey<String>('bottom-nav-scroll-viewport')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('En vivo'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(LiveChannelsScreen), findsOneWidget);
    expect(find.text('EVENTOS EN PREPARACIÓN O EN VIVO'), findsOneWidget);
    expect(find.text('8 REPRODUCTORES DISPONIBLES'), findsNothing);
    expect(find.text('SEÑAL PENDIENTE'), findsNothing);
    await tester.tap(find.text('Canales deportivos'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(AgendaChannelsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ajustes'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('MENÚ DAMIÁN APK'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });


}
