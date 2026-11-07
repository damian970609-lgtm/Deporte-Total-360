import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';

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
