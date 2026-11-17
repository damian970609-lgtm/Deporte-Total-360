import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
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

  test('el reproductor acepta contenedores progresivos de vídeo y audio', () {
    final extensions = <String>[
      'mp4', 'm4v', 'm4a', 'm4b', 'fmp4', 'mov', 'mkv', 'webm',
      'mp3', 'mp2', 'ogg', 'oga', 'opus', 'wav', 'aac', 'flac',
      'amr', 'ts', 'mpeg', 'mpg', 'vob', 'flv', 'm2ts', '2ts', 'mts',
    ];

    for (final extension in extensions) {
      final url = 'https://media.example/live.$extension?signature=abc';
      expect(isSupportedChannelPlaybackUrl(url), isTrue, reason: url);
      expect(videoFormatHintForUrl(url), VideoFormat.other, reason: url);
    }
  });

  test('detecta formatos adaptativos ocultos en parámetros de endpoints IPTV', () {
    expect(
      videoFormatHintForUrl('https://media.example/live.php?type=m3u8&token=abc'),
      VideoFormat.hls,
    );
    expect(
      videoFormatHintForUrl('https://media.example/play?id=1&format=mpd'),
      VideoFormat.dash,
    );
    expect(
      videoFormatHintForUrl('https://media.example/stream.php?protocol=smoothstream'),
      VideoFormat.ss,
    );
  });

  test('acepta endpoints HTTPS IPTV sin extensión y deja que ExoPlayer detecte el contenedor', () {
    const url = 'https://media.example/live/123456?token=abc';
    expect(isSupportedChannelPlaybackUrl(url), isTrue);
    expect(liveMediaFormatForUrl(url), LiveMediaFormat.progressive);
    expect(videoFormatHintForUrl(url), VideoFormat.other);
  });

  test('rechaza listas, páginas web, recursos gráficos, HTTP y URLs con credenciales', () {
    final urls = <String>[
      'https://media.example/channels.m3u',
      'https://media.example/channels.pls',
      'https://media.example/channels.xspf',
      'https://media.example/channels.xml',
      'https://media.example/channels.json',
      'https://media.example/channels.csv',
      'https://media.example/index.html',
      'https://media.example/logo.png',
      'https://media.example/watch.unknown',
      'http://media.example/live.m3u8',
      'https://user:password@media.example/live.m3u8',
      'not a url',
    ];

    for (final url in urls) {
      expect(isSupportedChannelPlaybackUrl(url), isFalse, reason: url);
    }
  });
}
