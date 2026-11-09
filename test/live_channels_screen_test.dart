import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('LiveFixture', () {
    test('lee identidad, hora, estado, marcadores y equipos del Worker', () {
      final fixture = LiveFixture.tryParse(
        <String, dynamic>{
          'fixture': <String, dynamic>{
            'id': 12345,
            'date': '2026-11-02T19:30:00Z',
            'status': <String, dynamic>{
              'short': '1H',
              'long': 'First Half',
            },
          },
          'league': <String, dynamic>{'name': 'Liga de prueba'},
          'teams': <String, dynamic>{
            'home': <String, dynamic>{
              'name': 'Equipo Azul',
              'logo': 'https://cdn.example/blue.png',
            },
            'away': <String, dynamic>{
              'name': 'Equipo Rojo',
              'logo': 'https://cdn.example/red.png',
            },
          },
          'goals': <String, dynamic>{'home': 2, 'away': 1},
        },
        'Fútbol',
      );

      expect(fixture, isNotNull);
      expect(fixture!.id, '12345');
      expect(fixture.competition, 'Liga de prueba');
      expect(fixture.homeTeam, 'Equipo Azul');
      expect(fixture.awayTeam, 'Equipo Rojo');
      expect(fixture.status, LiveFixtureStatus.live);
      expect(fixture.homeScore, 2);
      expect(fixture.awayScore, 1);
      expect(fixture.homeLogo, 'https://cdn.example/blue.png');
    });

    test('no inventa un evento cuando falta el horario o los equipos', () {
      expect(
        LiveFixture.tryParse(
          <String, dynamic>{
            'fixture': <String, dynamic>{'id': 1},
          },
          'Fútbol',
        ),
        isNull,
      );
    });
  });

  group('LiveStreamSource', () {
    test('persiste solo las señales directas válidas', () {
      final source = LiveStreamSource.fromJson(<String, dynamic>{
        'id': 'channel-1',
        'eventId': 'match-123',
        'eventTitle': 'Equipo Azul vs Equipo Rojo',
        'sport': 'Fútbol',
        'name': 'Señal oficial',
        'url': 'https://media.example/live.m3u8',
      });

      expect(source, isNotNull);
      expect(source!.eventId, 'match-123');
      expect(source.validatedUri!.path, '/live.m3u8');
    });

    test('identifica una señal llegada del catálogo remoto', () {
      final source = LiveStreamSource.fromCatalogJson(<String, dynamic>{
        'id': 'football-123-main',
        'eventId': '123',
        'eventTitle': 'Equipo Azul vs Equipo Rojo',
        'sport': 'football',
        'name': 'Señal oficial',
        'url': 'https://media.example/live.m3u8',
      });

      expect(source, isNotNull);
      expect(source!.isRemote, isTrue);
      expect(source.eventId, '123');
      expect(source.validatedUri!.scheme, 'https');
    });

    test('descarta un player web guardado como si fuera una señal', () {
      final source = LiveStreamSource.fromJson(<String, dynamic>{
        'id': 'bad-channel',
        'eventId': 'match-123',
        'eventTitle': 'Partido',
        'sport': 'Fútbol',
        'name': 'Página',
        'url': 'https://example.com/player?id=123',
      });

      expect(source, isNull);
    });
  });
}
