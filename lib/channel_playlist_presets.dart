/// Fuentes públicas de listas IPTV para el panel privado de Damián APK.
///
/// Las URLs son distintas entre sí. Algunas listas generales o regionales
/// pueden contener canales también presentes en otras fuentes; el catálogo
/// del servidor conserva el identificador de cada canal cuando está disponible.
const int maxChannelPlaylistSources = 12;

class ChannelPlaylistPreset {
  const ChannelPlaylistPreset({
    required this.label,
    required this.url,
    required this.description,
  });

  final String label;
  final String url;
  final String description;
}

const List<ChannelPlaylistPreset> channelPlaylistPresets =
    <ChannelPlaylistPreset>[
  ChannelPlaylistPreset(
    label: 'IPTV-org · Deportes',
    url: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
    description: 'Catálogo internacional organizado por categoría deportiva',
  ),
  ChannelPlaylistPreset(
    label: 'TDTChannels · TV España',
    url: 'https://www.tdtchannels.com/lists/tv.m3u',
    description: 'Televisión en abierto; incluye canales españoles e internacionales',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Deportes',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/categories/sports.m3u',
    description: 'Selección deportiva pública con comprobación periódica',
  ),
  ChannelPlaylistPreset(
    label: 'Free-TV · Global',
    url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
    description: 'Canales gratuitos internacionales, selección general',
  ),
  ChannelPlaylistPreset(
    label: 'FreecastHub · Deportes libres',
    url: 'https://raw.githubusercontent.com/freecasthub/public-iptv/main/sports.m3u',
    description: 'Canales deportivos públicos procedentes de fuentes oficiales',
  ),
  ChannelPlaylistPreset(
    label: 'Teleonline · TV abierta',
    url: 'https://teleonline.github.io/listas/tv.m3u8',
    description: 'Catálogo público de televisión en abierto',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Español',
    url: 'https://iptv-org.github.io/iptv/languages/spa.m3u',
    description: 'Canales que emiten en español',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · English',
    url: 'https://iptv-org.github.io/iptv/languages/eng.m3u',
    description: 'Canales que emiten en inglés',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · España',
    url: 'https://iptv-org.github.io/iptv/countries/es.m3u',
    description: 'Señales públicas clasificadas por país: España',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · México',
    url: 'https://iptv-org.github.io/iptv/countries/mx.m3u',
    description: 'Señales públicas clasificadas por país: México',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Argentina',
    url: 'https://iptv-org.github.io/iptv/countries/ar.m3u',
    description: 'Señales públicas clasificadas por país: Argentina',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Latinoamérica',
    url: 'https://iptv-org.github.io/iptv/regions/lac.m3u',
    description: 'Canales públicos de Latinoamérica y el Caribe',
  ),
];

/// Canonicaliza lo necesario para impedir altas repetidas de la misma URL.
/// Conserva la ruta y la consulta porque pueden identificar listas distintas.
String normalizeChannelPlaylistUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasAuthority) return trimmed;
  return uri
      .replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
        fragment: '',
      )
      .toString();
}

bool containsChannelPlaylistUrl(
  Iterable<String> existingUrls,
  String candidateUrl,
) {
  final candidate = normalizeChannelPlaylistUrl(candidateUrl);
  return existingUrls.any(
    (url) => normalizeChannelPlaylistUrl(url) == candidate,
  );
}
