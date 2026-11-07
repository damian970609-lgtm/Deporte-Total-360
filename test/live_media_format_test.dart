import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/live_media_format.dart';

void main() {
  test('el reproductor acepta HLS, DASH y Smooth Streaming directos por HTTPS', () {
    final urls = <String>[
      'https://media.example/live.m3u8?token=abc',
      'https://media.example/live/manifest.mpd?token=abc',
      'https://media.example/channel.ism/manifest',
      'https://media.example/channel.isml/manifest',
    ];

    for (final url in urls) {
      expect(isSupportedChannelPlaybackUrl(url), isTrue, reason: url);
    }
  });

  test('el reproductor acepta los contenedores progresivos clasificados', () {
    final extensions = <String>[
      'mp4', 'm4v', 'mov', 'mkv', 'webm', 'ts',
      'mpeg', 'mpg', 'flv', 'm2ts', '2ts', 'mts',
    ];

    for (final extension in extensions) {
      final url = 'https://media.example/live.$extension?signature=abc';
      expect(isSupportedChannelPlaybackUrl(url), isTrue, reason: url);
    }
  });

  test('rechaza listas, páginas web, HTTP y URLs con credenciales', () {
    final urls = <String>[
      'https://media.example/channels.m3u',
      'https://media.example/watch?id=123',
      'http://media.example/live.m3u8',
      'https://user:password@media.example/live.m3u8',
      'https://media.example/live.unknown',
      'not a url',
    ];

    for (final url in urls) {
      expect(isSupportedChannelPlaybackUrl(url), isFalse, reason: url);
    }
  });
}
