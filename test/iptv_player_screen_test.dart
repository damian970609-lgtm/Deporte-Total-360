import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/iptv_player_screen.dart';

void main() {
  group('fuente inicial del reproductor IPTV secreto', () {
    test('coloca deportes de iptv-org primero y conserva las listas propias', () {
      const customUrl = 'https://example.com/custom.m3u';
      expect(
        ensureSecretIptvSportsPlaylistFirst(<String>[customUrl]),
        <String>[defaultSecretIptvSportsPlaylistUrl, customUrl],
      );
    });

    test('no duplica la lista de deportes y la mueve al primer lugar', () {
      const customUrl = 'https://example.com/custom.m3u';
      expect(
        ensureSecretIptvSportsPlaylistFirst(<String>[
          customUrl,
          defaultSecretIptvSportsPlaylistUrl,
        ]),
        <String>[defaultSecretIptvSportsPlaylistUrl, customUrl],
      );
    });

    test('omite entradas inválidas sin perder las URLs HTTP/HTTPS guardadas', () {
      const customUrl = 'https://example.com/custom.m3u';
      expect(
        ensureSecretIptvSportsPlaylistFirst(<String>[
          'javascript:alert(1)',
          customUrl,
          customUrl,
        ]),
        <String>[defaultSecretIptvSportsPlaylistUrl, customUrl],
      );
    });
  });
}
