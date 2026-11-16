import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deporte_total_360/live_channels_screen.dart';
import 'package:video_player/video_player.dart';

void main() {
  testWidgets('la multivista incorpora automáticamente eventos nuevos', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(MaterialApp(
      home: LivePlayerGridScreen(
        sources: const <LivePlayerSource>[],
        refreshInterval: const Duration(seconds: 1),
        refreshSources: () async {
          refreshes++;
          return const <LivePlayerSource>[
            LivePlayerSource(title: 'Fútbol · Equipo Azul vs Equipo Rojo', url: 'https://media.example/one.m3u8'),
            LivePlayerSource(title: 'Fútbol · Equipo Verde vs Equipo Blanco', url: 'https://media.example/two.m3u8'),
          ];
        },
      ),
    ));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(refreshes, 1);
    expect(find.text('MULTIVISTA · 2/8 EVENTOS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets('la multivista admite ocho reproductores', (tester) async {
    final sources = List<LivePlayerSource>.generate(
      8,
      (index) => LivePlayerSource(
        title: 'Evento ${index + 1}',
        url: 'https://media.example/channel-${index + 1}.m3u8',
        subtitle: 'Canal ${index + 1}',
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: LivePlayerGridScreen(sources: sources),
    ));
    expect(find.text('MULTIVISTA · 8/8 EVENTOS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('la multivista inicia solo el primer directo y solo con la pestaña activa', () {
    expect(
      shouldAutomaticallyStartLiveSource(index: 0, isActive: true),
      isTrue,
    );
    expect(
      shouldAutomaticallyStartLiveSource(index: 1, isActive: true),
      isFalse,
    );
    expect(
      shouldAutomaticallyStartLiveSource(index: 0, isActive: false),
      isFalse,
    );
  });

  group('selector de resolución', () {
    test('presenta la altura disponible como resolución legible', () {
      const track = VideoTrack(
        id: 'video-720',
        isSelected: true,
        width: 1280,
        height: 720,
        bitrate: 2800000,
      );
      expect(videoTrackResolutionLabel(track), '720p');
    });

    test('usa la etiqueta del proveedor cuando no hay altura', () {
      const track = VideoTrack(
        id: 'video-auto',
        isSelected: false,
        label: 'HD',
        bitrate: 1500000,
      );
      expect(videoTrackResolutionLabel(track), 'HD');
    });
  });

  group('Validación de señales autorizadas', () {
    test('acepta HLS y MP4 directos por HTTP(S)', () {
      expect(
        isSupportedAuthorizedMediaUrl('https://media.example/live.m3u8'),
        isTrue,
      );
      expect(
        isSupportedAuthorizedMediaUrl('https://media.example/archive.mp4?token=abc'),
        isTrue,
      );
      expect(
        isSupportedAuthorizedMediaUrl('http://media.example/live.m3u8'),
        isTrue,
      );
      expect(
        isSupportedAuthorizedMediaUrl('https://media.example/live.ts'),
        isTrue,
      );
    });

    test('admite DASH y rechaza páginas web, RTMP y URLs con credenciales', () {
      expect(
        isSupportedAuthorizedMediaUrl('https://example.com/manifest.mpd'),
        isTrue,
      );
      expect(
        isSupportedAuthorizedMediaUrl('https://example.com/watch?v=123'),
        isFalse,
      );
      expect(
        isSupportedAuthorizedMediaUrl('https://example.com/channels.m3u'),
        isFalse,
      );
      expect(
        isSupportedAuthorizedMediaUrl('rtmp://example.com/live/stream'),
        isFalse,
      );
      expect(
        isSupportedAuthorizedMediaUrl('https://user:pass@example.com/live.m3u8'),
        isFalse,
      );
    });
  });

  testWidgets(
    'Deportes en vivo muestra ocho reproductores y limpia la configuración anterior',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'deporte_total_authorized_live_sources_v1': '[]',
        'deporte_total_live_favorites_v1': <String>['canal-antiguo'],
        'dt360_auto_live_playlist_url_v1': 'https://old.example/list.m3u',
        'dt360_auto_live_epg_url_v1': 'https://old.example/guide.xml',
        'dt360_auto_live_authorized_v1': true,
      });

      await tester.pumpWidget(
        const MaterialApp(home: LiveChannelsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(find.text('DEPORTES EN VIVO'), findsOneWidget);
      expect(find.text('8 REPRODUCTORES DISPONIBLES'), findsOneWidget);
      expect(find.text('SEÑAL PENDIENTE'), findsNWidgets(8));
      expect(find.text('ESPERANDO TRANSMISIÓN'), findsNWidgets(8));
      expect(find.text('PARTIDOS Y SEÑALES'), findsNothing);
      expect(find.text('CONFIGURAR GUÍAS EPG XMLTV'), findsNothing);
      expect(find.text('Buscar equipo, evento o competición'), findsNothing);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('deporte_total_authorized_live_sources_v1'), isFalse);
      expect(preferences.containsKey('deporte_total_live_favorites_v1'), isFalse);
      expect(preferences.getString('dt360_auto_live_playlist_url_v1'), '');
      expect(preferences.getString('dt360_auto_live_epg_url_v1'), '');
      expect(preferences.getBool('dt360_auto_live_authorized_v1'), isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
