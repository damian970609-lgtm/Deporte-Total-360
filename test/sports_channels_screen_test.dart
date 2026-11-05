import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/iptv_extractor_player_screen.dart';
import '../lib/sports_channels_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra los canales guardados en cuadrícula y permite buscarlos',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dt360_secret_iptv_playlist_urls_v1': <String>[
        defaultIptvStudioSportsUrl,
      ],
      'dt360_iptv_studio_default_added_v1': true,
    });
    final client = MockClient((request) async {
      return http.Response(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="sports.test.one" group-title="Fútbol",Canal Prueba\n'
        'https://media.example/uno.m3u8\n'
        '#EXTINF:-1 tvg-id="sports.test.two" group-title="Baloncesto",Otro Canal\n'
        'https://media.example/dos.m3u8\n',
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SportsChannelsScreen(
          httpClient: client,
          parseInBackground: false,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pump();

    expect(find.text('Canal Prueba'), findsOneWidget);
    expect(find.text('Otro Canal'), findsOneWidget);
    expect(find.text('CANALES DEPORTIVOS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Otro');
    await tester.pump();
    expect(find.text('Canal Prueba'), findsNothing);
    expect(find.text('Otro Canal'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
}
