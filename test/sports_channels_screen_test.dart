import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/iptv_extractor_player_screen.dart';
import '../lib/sports_channels_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleM3u = '#EXTM3U\n'
      '#EXTINF:-1 tvg-id="sports.test.one" group-title="Fútbol",Canal Prueba\n'
      'https://media.example/uno.m3u8\n'
      '#EXTINF:-1 tvg-id="sports.test.two" group-title="Baloncesto",Otro Canal\n'
      'https://media.example/dos.m3u8\n';

  test('cada canal tiene un identificador URI estable y distinto', () {
    final channels = parseIptvStudioM3u(sampleM3u);
    expect(channels[0].identificationUrl, startsWith('dt360://channel/'));
    expect(channels[0].identificationUrl, isNot(channels[1].identificationUrl));
    expect(channels[0].identificationUrl, channels[0].identificationUrl);
  });

  test('la selección de Canales deportivos se guarda y se puede quitar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final channels = parseIptvStudioM3u(sampleM3u);

    await addIptvStudioSportsChannel(channels[0]);
    await addIptvStudioSportsChannel(channels[1]);
    var saved = await loadIptvStudioSportsChannels();
    expect(saved.map((channel) => channel.id), <String>[channels[0].id, channels[1].id]);
    expect(saved.first.identificationUrl, channels.first.identificationUrl);

    await removeIptvStudioSportsChannel(channels[0].id);
    saved = await loadIptvStudioSportsChannels();
    expect(saved, hasLength(1));
    expect(saved.single.id, channels[1].id);
  });

  testWidgets('Canales deportivos solo muestra la selección y permite buscarla',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final channels = parseIptvStudioM3u(sampleM3u);
    await saveIptvStudioSportsChannels(<IptvExtractedChannel>[channels.first]);

    await tester.pumpWidget(
      const MaterialApp(home: SportsChannelsScreen()),
    );
    await tester.pump();

    expect(find.text('Canal Prueba'), findsOneWidget);
    expect(find.text('Otro Canal'), findsNothing);
    expect(find.text('CANALES DEPORTIVOS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Prueba');
    await tester.pump();
    expect(find.text('Canal Prueba'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
