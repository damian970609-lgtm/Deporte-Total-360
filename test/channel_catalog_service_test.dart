import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/channel_catalog_service.dart';

void main() {
  group('ChannelCatalogService.parseM3u', () {
    test('lee metadatos y limita formatos a HLS/DASH', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="sports.one" tvg-name="Sports One" group-title="Sports",Sports One HD
https://media.example/live/sports-one/playlist.m3u8
#EXTINF:-1 tvg-id="bad" group-title="Sports",Unsupported
https://media.example/live/unsupported.ts
#EXTINF:-1 tvg-id="sports.two" group-title="Sports",Sports Two
https://media.example/live/sports-two/manifest.mpd
''';
      final channels = ChannelCatalogService.parseM3u(playlist);
      expect(channels, hasLength(2));
      expect(channels.first.name, 'Sports One');
      expect(channels.first.tvgId, 'sports.one');
      expect(channels.first.group, 'Sports');
    });

    test('rechaza esquemas no HTTP y URL con credenciales', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="bad",Bad
file:///tmp/channel.m3u8
#EXTINF:-1 tvg-id="auth",Auth
https://user:pass@media.example/live/auth.m3u8
''';
      expect(ChannelCatalogService.parseM3u(playlist), isEmpty);
    });
  });

  test('XMLTV asocia la guía al partido usando los dos equipos y la hora', () {
    const epg = '''
<tv>
  <programme channel="sports.one" start="20261102180000 +0000" stop="20261102200000 +0000">
    <title>Live: Manchester City vs Arsenal</title>
  </programme>
</tv>
''';
    final suggestions = ChannelCatalogService.matchEvent(
      channels: const <TvCatalogChannel>[
        TvCatalogChannel(name: 'Sports One', url: 'https://media.example/sports/playlist.m3u8', tvgId: 'sports.one'),
      ],
      programmes: ChannelCatalogService.parseXmlTv(epg),
      sport: 'Fútbol',
      homeTeam: 'Manchester City',
      awayTeam: 'Arsenal',
      competition: 'Premier League',
      startsAt: DateTime.utc(2026, 11, 2, 18, 30),
    );
    expect(suggestions, hasLength(1));
    expect(suggestions.single.channelName, 'Sports One');
  });

  test('no sugiere la señal si el título no contiene ambos equipos', () {
    const epg = '''
<tv>
  <programme channel="sports.one" start="20261102180000 +0000" stop="20261102200000 +0000">
    <title>Live sports coverage</title>
  </programme>
</tv>
''';
    final suggestions = ChannelCatalogService.matchEvent(
      channels: const <TvCatalogChannel>[
        TvCatalogChannel(name: 'Sports One', url: 'https://media.example/sports/playlist.m3u8', tvgId: 'sports.one'),
      ],
      programmes: ChannelCatalogService.parseXmlTv(epg),
      sport: 'Fútbol',
      homeTeam: 'Manchester City',
      awayTeam: 'Arsenal',
      competition: 'Premier League',
      startsAt: DateTime.utc(2026, 11, 2, 18, 30),
    );
    expect(suggestions, isEmpty);
  });
}
