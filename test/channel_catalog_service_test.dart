import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';

void main() {
  test('las etiquetas compactas distinguen español e inglés', () {
    expect(channelLanguageDisplayLabel('es'), 'IDIOMA 🇪🇸');
    expect(channelLanguageDisplayLabel('en'), 'IDIOMA 🇺🇸');
  });

  test('no inventa bandera para idioma desconocido', () {
    expect(channelLanguageDisplayLabel('unknown'), isNull);
    expect(channelLanguageDisplayLabel('fr'), isNull);
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
          'total': 450,
          'offset': 200,
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
      offset: 200,
    );

    expect(requestedUri?.path, '/api/channels');
    expect(requestedUri?.queryParameters['q'], 'ESPN');
    expect(requestedUri?.queryParameters['offset'], '200');
    expect(page.total, 450);
    expect(page.offset, 200);
    expect(page.hasMore, isTrue);
    expect(page.channels, hasLength(1));
    expect(page.channels.single.name, 'ESPN Latino');
    client.close();
  });

}
