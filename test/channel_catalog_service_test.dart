import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/sports_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la copia local del catálogo conserva solo canales deportivos publicados', () async {
    final visibleSports = SportsChannel.fromJson(<String, dynamic>{
      'id': 'sports-visible',
      'identifier': 'sports-visible',
      'name': 'Canal Deportivo',
      'url': 'https://media.example/sports.m3u8',
      'isSports': true,
      'visible': true,
      'language': 'es',
    });
    final hiddenSports = SportsChannel.fromJson(<String, dynamic>{
      'id': 'sports-hidden',
      'identifier': 'sports-hidden',
      'name': 'Canal Oculto',
      'url': 'https://media.example/hidden.m3u8',
      'isSports': true,
      'visible': false,
    });
    final general = SportsChannel.fromJson(<String, dynamic>{
      'id': 'general-visible',
      'identifier': 'general-visible',
      'name': 'Canal General',
      'url': 'https://media.example/general.m3u8',
      'isSports': false,
      'visible': true,
    });
    SharedPreferences.setMockInitialValues({});
    await saveCachedPublicChannelSnapshot([
      visibleSports,
      hiddenSports,
      general,
    ]);

    final restored = await loadCachedVisibleSportsChannels();

    expect(restored.map((channel) => channel.id), ['sports-visible']);
  });

  SportsChannel snapshotChannel(String id, String name) {
    return SportsChannel.fromJson(<String, dynamic>{
      'id': id,
      'identifier': id,
      'name': name,
      'url': 'https://media.example/$id.m3u8',
      'isSports': true,
      'visible': true,
      'language': 'es',
    });
  }

  const snapshotSource = ChannelPlaylistSource(
    id: 'sports-list',
    url: 'https://lists.example/sports.m3u',
    label: 'Lista deportiva',
    status: 'imported',
    format: 'm3u',
    importedCount: 32,
    lastImportedAt: '2026-11-07T12:00:00Z',
  );


  test('el snapshot local evita consultar Cloudflare durante quince minutos', () async {
    SharedPreferences.setMockInitialValues({});
    final channel = snapshotChannel('espn-cache', 'ESPN');
    await saveCachedPublicChannelSnapshot([channel]);

    expect(
      await isCachedPublicChannelSnapshotFresh(
        maxAge: const Duration(minutes: 15),
      ),
      isTrue,
    );
    expect(
      await loadCachedVisibleSportsChannels(),
      hasLength(1),
    );
  });

  test('un snapshot viejo vuelve a permitir actualizar el catálogo remoto', () async {
    SharedPreferences.setMockInitialValues({
      channelCatalogSnapshotCacheKey: jsonEncode([
        snapshotChannel('espn-old', 'ESPN antiguo').toJson(),
      ]),
      channelCatalogSnapshotSavedAtKey:
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    });

    expect(
      await isCachedPublicChannelSnapshotFresh(
        maxAge: const Duration(minutes: 15),
      ),
      isFalse,
    );
    // La copia antigua sigue disponible como respaldo ante un fallo de cuota.
    expect((await loadCachedVisibleSportsChannels()).single.id, 'espn-old');
  });

  test('guardar fuentes no borra los canales guardados de la misma cuenta', () async {
    SharedPreferences.setMockInitialValues({});
    final channel = snapshotChannel('espn', 'ESPN');

    await ChannelAdminSnapshotStore.save(
      email: 'ADMIN@example.com',
      channels: [channel],
    );
    await ChannelAdminSnapshotStore.save(
      email: 'admin@example.com',
      sources: [snapshotSource],
    );

    final snapshot = await ChannelAdminSnapshotStore.load(
      email: 'Admin@example.com',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.hasChannels, isTrue);
    expect(snapshot.hasSources, isTrue);
    expect(snapshot.channels.map((item) => item.id), ['espn']);
    expect(snapshot.sources.map((item) => item.id), ['sports-list']);
  });

  test('guardar canales no borra las fuentes guardadas de la misma cuenta', () async {
    SharedPreferences.setMockInitialValues({});

    await ChannelAdminSnapshotStore.save(
      email: 'admin@example.com',
      sources: [snapshotSource],
    );
    await ChannelAdminSnapshotStore.save(
      email: 'admin@example.com',
      channels: [snapshotChannel('fox-sports', 'FOX Sports')],
    );

    final snapshot = await ChannelAdminSnapshotStore.load(
      email: 'admin@example.com',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.channels.single.name, 'FOX Sports');
    expect(snapshot.sources.single.id, 'sports-list');
  });

  test('serializa escrituras simultáneas de canales y fuentes sin perder datos', () async {
    SharedPreferences.setMockInitialValues({});

    await Future.wait([
      ChannelAdminSnapshotStore.save(
        email: 'admin@example.com',
        channels: [snapshotChannel('espn', 'ESPN')],
      ),
      ChannelAdminSnapshotStore.save(
        email: 'admin@example.com',
        sources: [snapshotSource],
      ),
    ]);

    final snapshot = await ChannelAdminSnapshotStore.load(
      email: 'admin@example.com',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.channels.map((item) => item.id), ['espn']);
    expect(snapshot.sources.map((item) => item.id), ['sports-list']);
  });

  test('mantiene aisladas las copias locales de cuentas diferentes', () async {
    SharedPreferences.setMockInitialValues({});

    await ChannelAdminSnapshotStore.save(
      email: 'admin-one@example.com',
      channels: [snapshotChannel('channel-one', 'Canal uno')],
      sources: [snapshotSource],
    );
    await ChannelAdminSnapshotStore.save(
      email: 'admin-two@example.com',
      channels: [snapshotChannel('channel-two', 'Canal dos')],
    );

    final first = await ChannelAdminSnapshotStore.load(
      email: 'admin-one@example.com',
    );
    final second = await ChannelAdminSnapshotStore.load(
      email: 'admin-two@example.com',
    );

    expect(first!.channels.single.id, 'channel-one');
    expect(first.sources.single.id, 'sports-list');
    expect(second!.channels.single.id, 'channel-two');
    expect(second.sources, isEmpty);
  });

  test('las fuentes de listas se pueden guardar y restaurar sin perder metadatos', () {
    const source = ChannelPlaylistSource(
      id: 'sports-list',
      url: 'https://lists.example/sports.m3u',
      label: 'Deportes',
      status: 'imported',
      format: 'm3u',
      lastError: '',
      importedCount: 32,
      lastImportedAt: '2026-11-07T12:00:00Z',
    );
    final restored = ChannelPlaylistSource.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.url, source.url);
    expect(restored.label, source.label);
    expect(restored.status, source.status);
    expect(restored.format, source.format);
    expect(restored.importedCount, source.importedCount);
    expect(restored.lastImportedAt, source.lastImportedAt);
  });

  test('parsea el permiso permanente de compra del servidor', () {
    final license = AppLicenseStatus.fromJson(<String, dynamic>{
      'allowed': true,
      'status': 'active',
      'licenseType': 'paid',
      'email': 'buyer@example.com',
    });

    expect(license.allowed, isTrue);
    expect(license.status, 'active');
    expect(license.licenseType, 'paid');
    expect(license.email, 'buyer@example.com');
  });

  test('parsea un pase gratuito y una licencia revocada', () {
    final free = AppLicenseRecord.fromJson(<String, dynamic>{
      'email': 'guest@example.com',
      'license_type': 'free',
      'status': 'active',
      'note': 'Invitación',
      'granted_at': '2026-11-06T12:00:00Z',
      'granted_by': 'damian970609@gmail.com',
    });
    final revoked = AppLicenseStatus.fromJson(<String, dynamic>{
      'allowed': false,
      'status': 'revoked',
      'licenseType': 'paid',
      'email': 'buyer@example.com',
    });

    expect(free.licenseType, 'free');
    expect(free.status, 'active');
    expect(free.note, 'Invitación');
    expect(revoked.allowed, isFalse);
    expect(revoked.status, 'revoked');
  });

  test('las etiquetas compactas distinguen español e inglés', () {
    expect(channelLanguageDisplayLabel('es'), 'IDIOMA 🇪🇸');
    expect(channelLanguageDisplayLabel('en'), 'IDIOMA 🇺🇸');
  });

  test('no inventa bandera para idioma desconocido', () {
    expect(channelLanguageDisplayLabel('unknown'), isNull);
    expect(channelLanguageDisplayLabel('fr'), isNull);
  });

  test('un pase VIP sin Google permite guardar y recuperar favoritos de canales', () async {
    SharedPreferences.setMockInitialValues({});
    final previousBase = sportsApiBaseUrl.value;
    sportsApiBaseUrl.value = 'https://worker-vip-favorites.example';
    final seenFavoriteHeaders = <Map<String, String>>[];
    final sessionToken = List<String>.filled(64, 'c').join();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/api/trials/redeem')) {
        return http.Response(jsonEncode({
          'activated': true,
          'sessionToken': sessionToken,
          'licenseType': 'trial',
          'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        }), 200);
      }
      if (request.url.path.endsWith('/api/trials/check')) {
        return http.Response(jsonEncode({
          'allowed': true,
          'status': 'active',
          'licenseType': 'trial',
        }), 200);
      }
      if (request.url.path.endsWith('/api/channels/favorites')) {
        seenFavoriteHeaders.add(Map<String, String>.from(request.headers));
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'channelIds': ['sports-channel-1']}), 200);
        }
        return http.Response(jsonEncode({'saved': true, 'count': 1}), 200);
      }
      return http.Response(jsonEncode({'error': 'Ruta inesperada'}), 404);
    });

    try {
      final service = ChannelCatalogService(client: client);
      await service.redeemTrialCode('ABCD1234EF567890ABCD');
      expect(await service.validateTrialSession(), isTrue);
      expect(await service.fetchFavorites(), {'sports-channel-1'});
      await service.saveFavorites({'sports-channel-1'});

      expect(seenFavoriteHeaders, hasLength(2));
      for (final headers in seenFavoriteHeaders) {
        final authorization = headers.entries
            .firstWhere((entry) => entry.key.toLowerCase() == 'authorization')
            .value;
        final deviceId = headers.entries
            .firstWhere((entry) => entry.key.toLowerCase() == 'x-dt360-device-id')
            .value;
        expect(authorization, 'Bearer $sessionToken');
        expect(deviceId, matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    } finally {
      sportsApiBaseUrl.value = previousBase;
      client.close();
    }
  });

  test('el catálogo puede serializar y restaurar canales completos para uso sin conexión', () {
    final original = SportsChannel.fromJson(<String, dynamic>{
      'id': 'espn-latino-1234',
      'identifier': 'espn-latino-1234',
      'name': 'ESPN Latino',
      'url': 'https://media.example/live.m3u8',
      'logoUrl': 'https://media.example/logo.png',
      'groupTitle': 'Deportes',
      'isSports': true,
      'visible': true,
      'language': 'es',
    });

    final restored = SportsChannel.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.identifier, original.identifier);
    expect(restored.name, original.name);
    expect(restored.url, original.url);
    expect(restored.logoUrl, original.logoUrl);
    expect(restored.groupTitle, original.groupTitle);
    expect(restored.isSports, original.isSports);
    expect(restored.visible, original.visible);
    expect(restored.language, original.language);
  });

  test('canal parseado mantiene el identificador y los metadatos', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'espn-latino-1234',
      'identifier': 'espn-latino-1234',
      'name': 'ESPN Latino',
      'url': 'https://media.example/live.m3u8',
      'logoUrl': 'https://media.example/logo.png',
      'groupTitle': 'Deportes',
      'isSports': true,
      'visible': true,
      'language': 'es',
    });

    expect(channel.identifier, 'espn-latino-1234');
    expect(channel.name, 'ESPN Latino');
    expect(channel.groupTitle, 'Deportes');
    expect(channel.isSports, isTrue);
    expect(channel.visible, isTrue);
    expect(channel.language, 'es');
  });

  test('canal rechaza HTTP aunque el enlace termine en una extensión compatible', () {
    expect(
      () => SportsChannel.fromJson(<String, dynamic>{
        'id': 'unsafe-http',
        'identifier': 'unsafe-http',
        'name': 'Canal HTTP',
        'url': 'http://media.example/live.m3u8',
        'isSports': true,
      }),
      throwsFormatException,
    );
  });

  test('canal admite señales MPEG-TS directas de listas M3U', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'canal-ts',
      'identifier': 'canal-ts',
      'name': 'Canal TS',
      'url': 'https://media.example/live.ts',
      'isSports': true,
    });
    expect(channel.url, endsWith('.ts'));
  });

  test('canal rechaza páginas web y streams que no sean HTTPS directos', () {
    expect(
      () => SportsChannel.fromJson(<String, dynamic>{
        'id': 'deporte',
        'identifier': 'deporte',
        'name': 'Canal',
        'url': 'https://media.example/watch',
        'isSports': true,
      }),
      throwsFormatException,
    );
  });

  test('canal rechaza URLs con credenciales', () {
    expect(
      () => SportsChannel.fromJson(<String, dynamic>{
        'id': 'deporte',
        'identifier': 'deporte',
        'name': 'Canal',
        'url': 'https://usuario:clave@media.example/live.m3u8',
        'isSports': true,
      }),
      throwsFormatException,
    );
  });

  test('canal conserva la etiqueta de idioma inglés', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'sports-en',
      'identifier': 'sports-en',
      'name': 'Sports Network',
      'url': 'https://media.example/english.m3u8',
      'language': 'en',
    });
    expect(channel.language, 'en');
  });

  test('canal sin idioma válido queda sin bandera', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'sports-unknown',
      'identifier': 'sports-unknown',
      'name': 'ESPN 2',
      'url': 'https://media.example/live.m3u8',
      'language': 'fr',
    });
    expect(channel.language, 'unknown');
  });

  test('un canal sin visibilidad explícita permanece oculto hasta su publicación', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'new-sports-channel',
      'identifier': 'new-sports-channel',
      'name': 'Canal deportivo nuevo',
      'url': 'https://media.example/new-channel.m3u8',
      'isSports': true,
    });

    expect(channel.visible, isFalse);
  });

  test('Google OAuth confirma que APK y Worker comparten el cliente Web', () async {
    final clientId = 'dt360-web.apps.googleusercontent.com';
    final client = MockClient((request) async {
      expect(request.url.path, '/api/channels/auth-config');
      return http.Response(
        jsonEncode(<String, Object>{
          'configured': true,
          'clientId': clientId,
        }),
        200,
      );
    });
    final service = ChannelCatalogService(
      client: client,
      googleServerClientId: clientId,
    );

    await expectLater(
      service.validateGoogleOAuthConfiguration(),
      completes,
    );
    client.close();
  });

  test('Google OAuth rechaza clientes Web distintos entre APK y Worker', () async {
    final client = MockClient((request) async => http.Response(
      jsonEncode(<String, Object>{
        'configured': true,
        'clientId': 'otro-cliente.apps.googleusercontent.com',
      }),
      200,
    ));
    final service = ChannelCatalogService(
      client: client,
      googleServerClientId: 'dt360-web.apps.googleusercontent.com',
    );

    await expectLater(
      service.validateGoogleOAuthConfiguration(),
      throwsA(isA<ChannelCatalogException>()),
    );
    client.close();
  });
  test('la carga pública devuelve una sola página y respeta la búsqueda', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode(<String, Object>{
          'configured': true,
          'total': 250001,
          'offset': 250000,
          'hasMore': true,
          'channels': <Map<String, Object>>[
            <String, Object>{
              'id': 'espn-latino',
              'identifier': 'espn-latino',
              'name': 'ESPN Latino',
              'url': 'https://media.example/espn.m3u8',
              'isSports': true,
              'visible': true,
              'language': 'es',
            },
          ],
        }),
        200,
      );
    });
    final service = ChannelCatalogService(client: client);

    final page = await service.fetchPublicChannelPage(
      search: 'ESPN',
      offset: 250000,
    );

    expect(requestedUri?.path, '/api/channels');
    expect(requestedUri?.queryParameters['q'], 'ESPN');
    expect(requestedUri?.queryParameters['offset'], '250000');
    expect(page.total, 250001);
    expect(page.offset, 250000);
    expect(page.hasMore, isTrue);
    expect(page.channels, hasLength(1));
    expect(page.channels.single.name, 'ESPN Latino');
    client.close();
  });

  test('el catálogo privado solicita el tamaño de página indicado para IPTV', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(jsonEncode(<String, Object>{
        'channels': <Object>[],
        'total': 4000,
        'offset': 2000,
        'hasMore': false,
      }), 200);
    });
    final service = ChannelCatalogService(client: client, accessTokenProvider: () => 'test-google-id-token');
    final page = await service.fetchAdminChannelPage(offset: 2000, limit: 2000);
    expect(requestedUri?.path, '/api/channels/admin/catalog');
    expect(requestedUri?.queryParameters['offset'], '2000');
    expect(requestedUri?.queryParameters['limit'], '2000');
    expect(page.offset, 2000);
    client.close();
  });

  test('editar una lista actualiza su nombre y URL mediante PUT autenticado', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(<String, Object>{'updated': true}), 200);
    });
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await service.updatePlaylistSource(
      id: 'source-123',
      url: 'https://lists.example/updated.m3u',
      label: 'Lista actualizada',
    );

    expect(sent?.method, 'PUT');
    expect(
      sent?.url.path,
      endsWith('/api/channels/admin/sources/source-123'),
    );
    expect(sent?.headers['Authorization'], 'Bearer test-google-id-token');
    expect(
      jsonDecode(sent!.body),
      <String, String>{
        'url': 'https://lists.example/updated.m3u',
        'label': 'Lista actualizada',
      },
    );
    client.close();
  });

  test('quitar una fuente usa DELETE y no altera otras rutas del catálogo', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(<String, Object>{
        'removed': true,
        'preservedChannels': true,
      }), 200);
    });
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await service.deletePlaylistSource(id: 'source-123');

    expect(sent?.method, 'DELETE');
    expect(sent?.url.path, endsWith('/api/channels/admin/sources/source-123'));
    client.close();
  });

  test('el canal DASH se conserva como señal multimedia compatible', () {
    final channel = SportsChannel.fromJson(<String, dynamic>{
      'id': 'sports-dash-1',
      'identifier': 'sports-dash-1',
      'name': 'Sports DASH',
      'url': 'https://media.example/live/manifest.mpd?token=sample',
      'isSports': true,
      'visible': false,
    });

    expect(channel.url, contains('.mpd'));
    expect(channel.isSports, isTrue);
    expect(channel.visible, isFalse);
  });

  test('clasificar un canal como deportivo usa PATCH autenticado', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(<String, Object>{
        'updated': true,
        'isSports': true,
        'visible': false,
      }), 200);
    });
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await service.setChannelSportsClassification(
      'news-channel-123',
      isSports: true,
    );

    expect(sent?.method, 'PATCH');
    expect(
      sent?.url.path,
      endsWith('/api/channels/admin/channels/news-channel-123/classification'),
    );
    expect(sent?.headers['Authorization'], 'Bearer test-google-id-token');
    expect(jsonDecode(sent!.body), <String, bool>{'isSports': true});
    client.close();
  });

  test('eliminar un canal usa DELETE autenticado en la ruta del canal', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(<String, Object>{
        'deleted': true,
        'blockedFromReimport': true,
      }), 200);
    });
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await service.deleteChannel('sports-channel-123');

    expect(sent?.method, 'DELETE');
    expect(
      sent?.url.path,
      endsWith('/api/channels/admin/channels/sports-channel-123'),
    );
    expect(sent?.headers['Authorization'], 'Bearer test-google-id-token');
    client.close();
  });

  test('eliminar un canal rechaza identificadores inseguros', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await expectLater(
      service.deleteChannel('../channel'),
      throwsA(isA<ChannelCatalogException>()),
    );
    client.close();
  });

  test('reintentar una fuente vuelve a ponerla en cola en el servidor', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(jsonEncode(<String, Object>{
        'queued': true,
      }), 202);
    });
    final service = ChannelCatalogService(
      client: client,
      accessTokenProvider: () => 'test-google-id-token',
    );

    await service.retryPlaylistSource(id: 'source-123');

    expect(sent?.method, 'POST');
    expect(sent?.url.path, endsWith('/api/channels/admin/sources/source-123/retry'));
    client.close();
  });
}
