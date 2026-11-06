import 'package:flutter_test/flutter_test.dart';
import 'package:deporte_total_360/channel_playlist_presets.dart';

void main() {
  test('ofrece las 13 listas predeterminadas con URLs HTTPS únicas', () {
    expect(channelPlaylistPresets, hasLength(13));
    expect(maxChannelPlaylistSources, greaterThanOrEqual(channelPlaylistPresets.length));

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

  test('incluye el índice global completo de IPTV-org sin quitar TDTChannels', () {
    expect(
      channelPlaylistPresets.any(
        (preset) =>
            preset.label == 'IPTV-org · Catálogo global completo' &&
            preset.url == 'https://iptv-org.github.io/iptv/index.m3u',
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
