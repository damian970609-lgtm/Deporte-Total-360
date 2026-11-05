import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/iptv_extractor_player_screen.dart';

void main() {
  group('IPTV Extractor 360 parser', () {
    test('extrae URLs HLS y endpoints directos sin extensión', () {
      const playlist = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="sports.one" group-title="Deportes",Canal Uno\n'
          'https://media.example/live/uno.m3u8?token=abc\n'
          '#EXTINF:-1 group-title="Deportes",Canal Dos\n'
          'https://media.example/live/channel/42\n'
          '#EXTINF:-1 group-title="Deportes",No válido\n'
          'ftp://media.example/live/no.mp4\n';
      final channels = parseIptvStudioM3u(playlist);
      expect(channels.map((channel) => channel.name), <String>[
        'Canal Uno',
        'Canal Dos',
      ]);
      expect(channels.first.url, contains('token=abc'));
      expect(channels[1].url, 'https://media.example/live/channel/42');
      expect(channels.first.id, startsWith('dt360-'));
    });

    test('rechaza HTML y listas que no contienen canales directos', () {
      expect(
        () => parseIptvStudioM3u('<html>error</html>'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseIptvStudioM3u(
          '#EXTM3U\n#EXTINF:-1,Lista anidada\nhttps://media.example/canales.m3u\n',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  testWidgets('carga la lista deportiva inicial y muestra los canales', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.toString());
      return http.Response(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="test.sport" group-title="Deportes",Canal Prueba\n'
        'https://media.example/test.m3u8\n',
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: IptvExtractorPlayerScreen(
          httpClient: client,
          parseInBackground: false,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(requested, contains(defaultIptvStudioSportsUrl));
    expect(find.text('Canal Prueba'), findsOneWidget);
    expect(find.byTooltip('Acciones del canal'), findsOneWidget);

    await tester.tap(find.text('Canal Prueba'));
    expect(iptvSelectedSportsChannel.value?.name, 'Canal Prueba');
    iptvSelectedSportsChannel.value = null;

    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
