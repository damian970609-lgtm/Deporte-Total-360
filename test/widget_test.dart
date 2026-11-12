import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/agenda_screen.dart';
import 'package:deporte_total_360/main.dart';
import 'package:deporte_total_360/channel_catalog_screen.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/channel_local_iptv_store.dart';
import 'package:deporte_total_360/channel_playlist_presets.dart';
import 'package:deporte_total_360/sports_api_service.dart';

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
  int sourceFetchCalls = 0;
  int lastAdminPageLimit = 0;
  final List<Map<String, Object>> visibilityRequests = <Map<String, Object>>[];
  final Map<String, String> languageRequests = <String, String>{};
  final List<String> deletedSourceIds = <String>[];
  final List<Map<String, String>> addedPlaylistRequests =
      <Map<String, String>>[];
  final List<List<Map<String, String>>> bulkPlaylistRequests =
      <List<Map<String, String>>>[];
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
    sourceFetchCalls++;
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
  }) async {
    bulkPlaylistRequests.add(
      sources.map((source) => Map<String, String>.from(source)).toList(),
    );
    final before = _storedSourceCount;
    _storedSourceCount = 120;
    return <String, dynamic>{
      'added': 120 - before,
      'duplicates': before,
      'total': 120,
      'limit': 120,
      'complete': true,
    };
  }

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
  Future<void> setVisibility(
    String channelId, {
    required bool visible,
  }) async {
    visibilityRequests.add(<String, Object>{
      'channelId': channelId,
      'visible': visible,
    });
  }

  @override
  Future<void> setLanguage(
    String channelId, {
    required String language,
  }) async {
    languageRequests[channelId] = language;
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
  testWidgets('la agenda de fútbol muestra por defecto los próximos siete días', (tester) async {
    sportsApiBaseUrl.value = '';
    await tester.pumpWidget(
      const MaterialApp(home: AgendaScreen(initialSport: 'Fútbol')),
    );

    expect(find.text('Próximos 7 días'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
  });

  testWidgets('DAMIAN.APK abre un único panel tras diez pulsaciones y evita apilar rutas', (tester) async {
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
    expect(find.text('120 LISTAS IPTV'), findsNothing);

    final tapTarget = find.ancestor(
      of: signature,
      matching: find.byType(GestureDetector),
    ).first;
    final onTap = tester.widget<GestureDetector>(tapTarget).onTap!;
    onTap();
    // Simula toques adicionales durante la transición de apertura.
    for (var tap = 0; tap < 30; tap++) {
      onTap();
    }
    await tester.pumpAndSettle();

    expect(
      find.text('120 LISTAS IPTV', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('ENTRAR CON GOOGLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('una copia IPTV completa se abre sin consultar de nuevo al servidor', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final directory = await Directory.systemTemp.createTemp('dt360-widget-cache-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final localStore = ChannelLocalIptvStore(
      directoryProvider: () async => directory,
    );
    final cachedChannels = List<SportsChannel>.generate(
      85,
      (index) => SportsChannel(
        id: 'cached-$index',
        identifier: 'cached-$index',
        name: 'Canal cacheado ${index.toString().padLeft(3, '0')}',
        url: 'https://media.example/cached-$index.m3u8',
        isSports: index.isEven,
        visible: index.isOdd,
        language: index.isEven ? 'es' : 'en',
      ),
      growable: false,
    );
    final cachedSources = List<ChannelPlaylistSource>.generate(
      120,
      (index) => ChannelPlaylistSource(
        id: 'cached-source-$index',
        url: 'https://lists.example/cached-$index.m3u',
        label: 'Lista guardada $index',
        status: 'imported',
        importedCount: index,
      ),
      growable: false,
    );
    await localStore.save(
      email: 'admin@example.com',
      channels: cachedChannels,
      sources: cachedSources,
      complete: true,
      nextOffset: cachedChannels.length,
    );

    final service = _AdminTestService(autoSignIn: true, offline: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ChannelAdminScreen(
          service: service,
          localStore: localStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canal cacheado 000'), findsOneWidget);
    expect(find.text('120 LISTAS IPTV · TODOS LOS CANALES'), findsOneWidget);
    expect(service._adminPageCalls, 0);
    expect(service.sourceFetchCalls, 0);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
    expect(find.text('CARGAR SIGUIENTE BLOQUE'), findsNothing);

    final lastLanguage = find.byKey(
      const ValueKey<String>('iptv-language-cached-84'),
    );
    await tester.scrollUntilVisible(
      lastLanguage,
      500,
      scrollable: find.byKey(
        const ValueKey<String>('channel-admin-iptv-list'),
      ),
    );
    expect(lastLanguage, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú privado muestra todos los canales en una sola pestaña IPTV', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.text('120 LISTAS IPTV · TODOS LOS CANALES'), findsOneWidget);
    expect(find.text('Canal General'), findsOneWidget);
    expect(find.text('ESPN Deportes'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
    expect(find.text('AÑADIR CANALES Y LISTAS IPTV'), findsNothing);
    expect(service.lastAdminPageLimit, 2000);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la pestaña IPTV muestra las fuentes sin botones de administración', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(
      const ValueKey<String>('channel-admin-iptv-list'),
    );
    await tester.scrollUntilVisible(
      find.text('Lista importada'),
      400,
      scrollable: list,
    );
    expect(find.text('Lista importada'), findsOneWidget);
    expect(find.text('AÑADIR ÍNDICE GLOBAL IPTV-ORG'), findsNothing);
    expect(find.text('AÑADIR LISTA GENERAL'), findsNothing);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('QUITAR LISTA'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('completa automáticamente las 120 fuentes registradas', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true, sourceCount: 99);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(service.bulkPlaylistRequests, hasLength(1));
    expect(service.bulkPlaylistRequests.single, hasLength(120));
    expect(
      service.bulkPlaylistRequests.single.any(
        (source) =>
            source['url'] == iptvOrgGlobalIndexPlaylistUrl &&
            source['label'] == iptvOrgGlobalIndexPlaylistLabel,
      ),
      isTrue,
    );
    expect(service.refreshRequested, isFalse);
    expect(find.text('120/120'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el menú no permite agregar ni borrar fuentes desde la pestaña IPTV', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AÑADIR LISTA GENERAL'), findsNothing);
    expect(find.text('AGREGAR CANALES DESDE ESTA LISTA'), findsNothing);
    expect(find.text('EDITAR'), findsNothing);
    expect(find.text('REINTENTAR'), findsNothing);
    expect(find.text('QUITAR LISTA'), findsNothing);
    expect(service.addedPlaylistRequests, isEmpty);
    expect(service.deletedSourceIds, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la vista IPTV no muestra pestaña administrativa ni controles de proxy', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('120 LISTAS IPTV'), findsOneWidget);
    expect(find.text('REPRODUCTOR IPTV'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
    expect(find.text('PROTON VPN'), findsNothing);
    expect(find.text('PROXY 0/10'), findsNothing);
    expect(find.text('AÑADIR CANALES Y LISTAS IPTV'), findsNothing);

    final list = find.byKey(
      const ValueKey<String>('channel-admin-iptv-list'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('iptv-add-channel-general-channel')),
      300,
      scrollable: list,
    );
    expect(
      find.byTooltip('Configurar proxies de Canal General'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el catálogo local no ofrece botones para volver a descargar las listas', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _AdminTestService(autoSignIn: true);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Descarga completa y guardada'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.text('REIMPORTAR LISTAS GUARDADAS · TODOS LOS CANALES'), findsNothing);
    expect(service.refreshRequested, isFalse);
    expect(find.text('Canal General'), findsOneWidget);
    expect(find.text('ESPN Deportes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel IPTV exige autenticación antes de mostrar las listas', (tester) async {
    final service = _AdminTestService(autoSignIn: false);
    await tester.pumpWidget(
      MaterialApp(home: ChannelAdminScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CATÁLOGO IPTV PRIVADO'), findsOneWidget);
    expect(find.text('ENTRAR CON GOOGLE'), findsOneWidget);
    expect(find.text('120 LISTAS IPTV · TODOS LOS CANALES'), findsNothing);
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

  testWidgets('descarga una vez los canales, conserva idioma y visibilidad al reabrir', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final directory = await Directory.systemTemp.createTemp('dt360-iptv-widget-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final localStore = ChannelLocalIptvStore(
      directoryProvider: () async => directory,
    );
    final firstService = _AdminTestService(
      autoSignIn: true,
      adminTotal: 2005,
      sourceCount: 120,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChannelAdminScreen(
          service: firstService,
          localStore: localStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey<String>('iptv-channel-total')),
      ).data,
      '2005',
    );
    expect(firstService._adminPageCalls, 2);
    expect(firstService.sourceFetchCalls, 1);
    expect(find.text('AÑADIR CANALES Y LISTAS IPTV'), findsNothing);
    expect(find.text('TODOS LOS CANALES IMPORTADOS'), findsNothing);

    final language = find.byKey(
      const ValueKey<String>('iptv-language-general-channel'),
    );
    expect(language, findsOneWidget);
    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inglés').last);
    await tester.pumpAndSettle();
    expect(firstService.languageRequests['general-channel'], 'en');

    final visibility = find.byKey(
      const ValueKey<String>('iptv-add-channel-general-channel'),
    );
    expect(visibility, findsOneWidget);
    await tester.tap(visibility);
    await tester.pumpAndSettle();
    expect(firstService.visibilityRequests, contains(<String, Object>{
      'channelId': 'general-channel',
      'visible': true,
    }));

    final saved = await localStore.load(email: 'admin@example.com');
    expect(saved, isNotNull);
    expect(saved!.complete, isTrue);
    expect(saved.channels, hasLength(2005));
    final savedGeneral = saved.channels.firstWhere(
      (channel) => channel.id == 'general-channel',
    );
    expect(savedGeneral.language, 'en');
    expect(savedGeneral.visible, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    final secondService = _AdminTestService(
      autoSignIn: true,
      adminTotal: 1,
      sourceCount: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChannelAdminScreen(
          service: secondService,
          localStore: localStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(
        find.byKey(const ValueKey<String>('iptv-channel-total')),
      ).data,
      '2005',
    );
    expect(secondService._adminPageCalls, 0);
    expect(secondService.sourceFetchCalls, 0);
    expect(
      tester.widget<DropdownButton<String>>(language).value,
      'en',
    );
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

  testWidgets('las flechas de navegación nunca cubren etiquetas antes ni después de desplazar', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    void expectNoNavigationLabelBehindCues() {
      final viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('bottom-nav-scroll-viewport')),
      );
      final labels = List<Finder>.generate(
        7,
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

  testWidgets('muestra las siete secciones principales y presenta Chat y Ajustes', (tester) async {
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
    expect(find.text('Actualizar APK'), findsNothing);
    expect(find.text('Ajustes'), findsOneWidget);
    // La sala pública no arranca hasta seleccionar su pestaña.
    expect(find.text('CHAT DE COMPRADORES'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la navegación inferior permite recorrer las siete secciones', (tester) async {
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

  testWidgets('Agenda abre dentro del shell y conserva la pantalla ante un fallo de SportsAPI', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sportsApiBaseUrl.value = '';

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    final agendaTab = find.text('Agenda de hoy');
    await tester.ensureVisible(agendaTab);
    await tester.tap(agendaTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('AGENDA DEPORTIVA'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agenda-process-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('agenda-process-status')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    sportsApiBaseUrl.value = defaultSportsApiBaseUrl;
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
