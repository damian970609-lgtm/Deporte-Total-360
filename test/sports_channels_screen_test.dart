import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  MockClient clientForSample() => MockClient(
        (_) async => http.Response(sampleM3u, 200),
      );

  test('cada canal tiene un identificador URI estable y distinto', () {
    final channels = parseIptvStudioM3u(sampleM3u);
    expect(channels[0].identificationUrl, startsWith('dt360://channel/'));
    expect(channels[0].identificationUrl, isNot(channels[1].identificationUrl));
    expect(
      parseIptvStudioM3u(sampleM3u)[0].identificationUrl,
      channels[0].identificationUrl,
    );
  });

  test('canales con el mismo tvg-id conservan identificadores separados', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final channels = parseIptvStudioM3u(
      '#EXTM3U\n'
      '#EXTINF:-1 tvg-id="duplicated" group-title="Deportes",Canal A\n'
      'https://media.example/a.m3u8\n'
      '#EXTINF:-1 tvg-id="duplicated" group-title="Deportes",Canal B\n'
      'https://media.example/b.m3u8\n',
    );

    expect(channels[0].id, channels[1].id);
    expect(channels[0].identificationUrl, isNot(channels[1].identificationUrl));
    await saveIptvStudioSportsChannels(channels);
    expect(await loadIptvStudioSportsChannels(), hasLength(2));
    await removeIptvStudioSportsChannel(channels[0].identificationUrl);
    final remaining = await loadIptvStudioSportsChannels();
    expect(remaining, hasLength(1));
    expect(remaining.single.name, 'Canal B');
  });

  test('la primera lista se agrega automáticamente y permite añadir más', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final urls = await loadIptvStudioPlaylistUrls();
    expect(urls, contains(defaultIptvStudioSportsUrl));

    await addIptvStudioPlaylistUrls(<String>[
      'https://listas.example/deportes.m3u',
      'https://listas.example/television.m3u',
    ]);
    final saved = await loadIptvStudioPlaylistUrls();
    expect(saved, contains(defaultIptvStudioSportsUrl));
    expect(saved, contains('https://listas.example/deportes.m3u'));
    expect(saved, contains('https://listas.example/television.m3u'));
  });

  test('ocultar un canal lo conserva en la lista oculta para el menú secreto', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final channel = parseIptvStudioM3u(sampleM3u).first;

    await setIptvStudioChannelHidden(
      channel.identificationUrl,
      true,
      channel: channel,
    );
    expect(
      await loadIptvStudioHiddenChannelIds(),
      contains(channel.identificationUrl),
    );
    expect(
      (await loadIptvStudioHiddenChannels())
          .map((item) => item.identificationUrl),
      contains(channel.identificationUrl),
    );

    await setIptvStudioChannelHidden(channel.identificationUrl, false);
    expect(
      await loadIptvStudioHiddenChannelIds(),
      isNot(contains(channel.identificationUrl)),
    );
  });

  testWidgets(
      'Canales deportivos solo muestra canales habilitados desde Damián APK',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await addIptvStudioPlaylistUrls(<String>[
      'https://listas.example/deportes.m3u',
    ]);
    final channels = parseIptvStudioM3u(sampleM3u);

    await tester.pumpWidget(
      const MaterialApp(home: SportsChannelsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('CANALES DEPORTIVOS'), findsOneWidget);
    expect(find.text('Canal Prueba'), findsNothing);
    expect(find.text('Otro Canal'), findsNothing);
    expect(find.byTooltip('Agregar más listas'), findsNothing);
    expect(find.byTooltip('Buscar canal por nombre'), findsOneWidget);

    await addIptvStudioSportsChannel(channels.first);
    await tester.pumpAndSettle();

    expect(find.text('Canal Prueba'), findsOneWidget);
    expect(find.text('Otro Canal'), findsNothing);
    expect(find.byTooltip('Buscar canal por nombre'), findsOneWidget);

    final hideButton = find.byTooltip('Ocultar canal').first;
    await tester.ensureVisible(hideButton);
    await tester.pumpAndSettle();
    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    expect(find.text('Canal Prueba'), findsNothing);
    expect(await loadIptvStudioSportsChannels(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'el menú secreto activa y desactiva canales en Canales deportivos',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await addIptvStudioPlaylistUrls(<String>[
      'https://listas.example/deportes.m3u',
    ]);
    final channel = parseIptvStudioM3u(sampleM3u).first;

    await tester.pumpWidget(
      MaterialApp(
        home: IptvExtractorPlayerScreen(
          httpClient: clientForSample(),
          parseInBackground: false,
        ),
      ),
    );
    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text(channel.name), findsOneWidget);
    expect(find.textContaining('NO VISIBLE EN CANALES DEPORTIVOS'), findsNWidgets(2));

    final showButton = find.byTooltip('Mostrar en Canales deportivos').first;
    await tester.ensureVisible(showButton);
    await tester.pumpAndSettle();
    await tester.tap(showButton);
    await tester.pumpAndSettle();

    expect(
      (await loadIptvStudioSportsChannels())
          .map((item) => item.identificationUrl),
      contains(channel.identificationUrl),
    );
    expect(find.textContaining('· VISIBLE EN CANALES DEPORTIVOS'), findsOneWidget);

    final hideButton = find.byTooltip('Ocultar en Canales deportivos').first;
    await tester.ensureVisible(hideButton);
    await tester.pumpAndSettle();
    await tester.tap(hideButton);
    await tester.pumpAndSettle();
    expect(await loadIptvStudioSportsChannels(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

}
