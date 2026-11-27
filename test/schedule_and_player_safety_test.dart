import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deporte_total_360/agenda_live_service.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';
import 'package:deporte_total_360/live_media_format.dart';

void main() {

  test('conserva varias referencias de canal encontradas en una ficha', () {
    final event = AgendaEventReference.tryParse(<String, Object>{
      'id': 'evento-canales',
      'title': 'Equipo A vs Equipo B',
      'startsAt': DateTime.now().toIso8601String(),
      'channelReferences': <String>[
        'Fuente 1: Canal no disponible',
        'Fuente 2: Disney+ · Español',
      ],
    });

    expect(event, isNotNull);
    expect(event!.channelReferences, <String>[
      'canal no disponible',
      'disney',
    ]);
  });

  test('asigna un solo canal aunque el evento tenga varias opciones', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final start = DateTime.now();
    final service = AgendaLiveService();

    await service.captureAgendaEvents(<Map<String, Object>>[
      <String, Object>{
        'id': 'evento-una-senal',
        'title': 'Equipo A vs Equipo B',
        'startsAt': start.toIso8601String(),
        'channelReferences': <String>[
          'Fuente 1: Canal inexistente',
          'Fuente 2: Disney+',
          'Fuente 3: ESPN 2',
        ],
      },
    ]);

    final board = await service.buildBoardState(
      now: start.add(const Duration(minutes: 1)),
      channels: <SportsChannel>[
        const SportsChannel(
          id: 'disney',
          identifier: 'disney',
          name: 'Disney+',
          url: 'https://media.example.org/disney/live.m3u8',
          isSports: true,
          visible: true,
          language: 'es',
        ),
        const SportsChannel(
          id: 'espn-2',
          identifier: 'espn-2',
          name: 'ESPN 2',
          url: 'https://media.example.org/espn2/live.m3u8',
          isSports: true,
          visible: true,
          language: 'es',
        ),
      ],
    );

    expect(board.assignments, hasLength(1));
    expect(board.assignments.single.channel.name, 'Disney+');
  });

  test('normaliza el nombre del canal y conserva su número', () {
    expect(
      normalizeAgendaChannelReference('Fuente 1: ESPN2 · Español'),
      'espn 2',
    );
    expect(
      normalizeAgendaChannelReference('Canal 2: DSports HD'),
      'dsports',
    );
  });

  test('acepta una fuente HLS directa por HTTPS', () {
    expect(
      liveMediaFormatForUrl('https://media.example.org/live/event.m3u8?token=abc'),
      LiveMediaFormat.hls,
    );
    expect(
      isSupportedChannelPlaybackUrl('https://media.example.org/live/event.m3u8'),
      isTrue,
    );
  });

  test('rechaza páginas de eventos y flujos HTTP no seguros', () {
    expect(
      liveMediaFormatForUrl('https://futbol-libre.cam/evento/123'),
      isNull,
    );
    expect(
      isSupportedChannelPlaybackUrl('http://media.example.org/live/event.m3u8'),
      isFalse,
    );
  });
}
