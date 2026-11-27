import 'package:flutter_test/flutter_test.dart';

import 'package:deporte_total_360/agenda_live_service.dart';
import 'package:deporte_total_360/live_media_format.dart';

void main() {
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
