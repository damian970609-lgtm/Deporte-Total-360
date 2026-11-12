import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/channel_playlist_presets.dart';

void main() {
  test('ofrece exactamente 120 listas predeterminadas con URLs HTTPS únicas', () {
    expect(channelPlaylistPresets, hasLength(120));
    expect(maxChannelPlaylistSources, equals(120));

    final normalizedUrls = channelPlaylistPresets
        .map((preset) => normalizeChannelPlaylistUrl(preset.url))
        .toSet();

    expect(normalizedUrls, hasLength(channelPlaylistPresets.length));
    expect(
      channelPlaylistPresets.every(
        (preset) => Uri.parse(preset.url).scheme == 'https',
      ),
      isTrue,
    );
  });

  test('incluye la lista de TV de TDTChannels solicitada', () {
    expect(
      channelPlaylistPresets.any(
        (preset) =>
            preset.label == 'TDTChannels · TV España' &&
            preset.url == 'https://www.tdtchannels.com/lists/tv.m3u',
      ),
      isTrue,
    );
  });

  test('incluye la lista combinada de TV y radio de TDTChannels', () {
    expect(
      channelPlaylistPresets.any(
        (preset) =>
            preset.label == 'TDTChannels · TV + Radio' &&
            preset.url == 'https://www.tdtchannels.com/lists/tvradio.m3u',
      ),
      isTrue,
    );
  });

  test('incluye el índice Everything de dearbulut en la plaza 100 y conserva TDTChannels', () {
    expect(
      channelPlaylistPresets.any(
        (preset) =>
            preset.label == dearbulutEverythingPlaylistLabel &&
            preset.url == 'https://dearbulut.github.io/iptv/playlists/index.m3u',
      ),
      isTrue,
    );
    expect(
      channelPlaylistPresets.any(
        (preset) =>
            preset.label == 'TDTChannels · TV España' &&
            preset.url == 'https://www.tdtchannels.com/lists/tv.m3u',
      ),
      isTrue,
    );
  });

  test('incluye veinte fuentes nuevas de países sin duplicar URLs', () {
    expect(channelPlaylistPresets[99].url, dearbulutEverythingPlaylistUrl);
    expect(channelPlaylistPresets.skip(100), hasLength(20));
    expect(channelPlaylistPresets.map((preset) => normalizeChannelPlaylistUrl(preset.url)).toSet(), hasLength(120));
  });

  test('incluye ocho fuentes deportivas públicas adicionales', () {
    expect(channelSportsPlaylistPresets, hasLength(8));
    expect(
      channelSportsPlaylistPresets.every(
        (preset) => Uri.parse(preset.url).scheme == 'https',
      ),
      isTrue,
    );
    expect(
      channelSportsPlaylistPresets.map((preset) => preset.url).toSet(),
      hasLength(8),
    );
  });

  test('detecta URLs repetidas aunque cambie el uso de mayúsculas del host', () {
    expect(
      containsChannelPlaylistUrl(
        <String>['https://EXAMPLE.com/list.m3u#section'],
        'https://example.com/list.m3u',
      ),
      isTrue,
    );
  });

  test('conserva diferentes rutas como listas diferentes', () {
    expect(
      containsChannelPlaylistUrl(
        <String>['https://example.com/sports.m3u'],
        'https://example.com/tv.m3u',
      ),
      isFalse,
    );
  });
}
