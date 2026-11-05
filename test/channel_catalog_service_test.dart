import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';

void main() {
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
}


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
