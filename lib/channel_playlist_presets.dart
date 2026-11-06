/// Fuentes públicas de listas IPTV para el panel privado de Damián APK.
///
/// Las URLs son distintas entre sí. Algunas listas generales o regionales
/// pueden contener canales también presentes en otras fuentes; el catálogo
/// del servidor conserva el identificador de cada canal cuando está disponible.
const int maxChannelPlaylistSources = 48;

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
    label: 'IPTV Validated · Catálogo verificado',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlist.m3u',
    description: 'Catálogo público con comprobación diaria de disponibilidad y prioridad para señales sin restricciones',
  ),
  ChannelPlaylistPreset(
    label: 'FreecastHub · Noticias públicas',
    url: 'https://raw.githubusercontent.com/freecasthub/public-iptv/main/news.m3u',
    description: 'Canales informativos gratuitos de emisoras públicas y oficiales',
  ),
  ChannelPlaylistPreset(
    label: 'FreecastHub · Educación pública',
    url: 'https://raw.githubusercontent.com/freecasthub/public-iptv/main/education.m3u',
    description: 'Canales educativos gratuitos de fuentes públicas',
  ),
  ChannelPlaylistPreset(
    label: 'FreecastHub · Clima y tiempo',
    url: 'https://raw.githubusercontent.com/freecasthub/public-iptv/main/weather.m3u',
    description: 'Canales públicos dedicados al clima y la información meteorológica',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Documentales',
    url: 'https://iptv-org.github.io/iptv/categories/documentary.m3u',
    description: 'Emisoras públicas y canales abiertos de documentales',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Infantil',
    url: 'https://iptv-org.github.io/iptv/categories/kids.m3u',
    description: 'Canales infantiles de acceso público',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Películas',
    url: 'https://iptv-org.github.io/iptv/categories/movies.m3u',
    description: 'Canales abiertos de películas y cine',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Música',
    url: 'https://iptv-org.github.io/iptv/categories/music.m3u',
    description: 'Canales musicales de libre acceso',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Cultura',
    url: 'https://iptv-org.github.io/iptv/categories/culture.m3u',
    description: 'Canales culturales y de divulgación públicos',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Noticias',
    url: 'https://iptv-org.github.io/iptv/categories/news.m3u',
    description: 'Canales informativos abiertos de distintos países',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Entretenimiento',
    url: 'https://iptv-org.github.io/iptv/categories/entertainment.m3u',
    description: 'Canales gratuitos de entretenimiento de fuentes públicas',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Deportes',
    url: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
    description: 'Catálogo internacional organizado por categoría deportiva',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Catálogo global completo',
    url: 'https://iptv-org.github.io/iptv/index.m3u',
    description: 'Índice mundial completo del proyecto IPTV-org, con canales públicos de múltiples países',
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


/// Fuentes deportivas públicas adicionales. Las listas generales se importan
/// pero el catálogo solo publica como deportivos los canales reconocidos por
/// nombre o categoría.
const List<ChannelPlaylistPreset> channelSportsPlaylistPresets =
    <ChannelPlaylistPreset>[
  ChannelPlaylistPreset(
    label: 'IPTV-org · Deportes',
    url: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
    description: 'Categoría deportiva del directorio comunitario IPTV-org',
  ),
  ChannelPlaylistPreset(
    label: 'FreecastHub · Deportes públicos',
    url: 'https://raw.githubusercontent.com/freecasthub/public-iptv/main/sports.m3u',
    description: 'Canales deportivos que el repositorio identifica como públicos y gratuitos',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Deportes',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/categories/sports.m3u',
    description: 'Selección deportiva con comprobación periódica de disponibilidad',
  ),
  ChannelPlaylistPreset(
    label: 'Doubo · Deportes públicos',
    url: 'https://cdn.jsdelivr.net/gh/streamline-iptv/iptv-playlists@dist/categories/sports.m3u',
    description: 'Categoría deportiva de un directorio público actualizado',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV By Shovo · Global con filtro deportivo',
    url: 'https://shovo127.github.io/IPTV-By-Shovo/index.m3u',
    description: 'Directorio global; la app conserva únicamente los canales detectados como deportivos',
  ),
  ChannelPlaylistPreset(
    label: 'Free-TV · Global con filtro deportivo',
    url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
    description: 'Directorio público general; la app filtra canales por nombre y categoría deportiva',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Deportes al aire libre',
    url: 'https://iptv-org.github.io/iptv/categories/outdoor.m3u',
    description: 'Actividades deportivas y canales de exteriores',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV-org · Motor y automoción',
    url: 'https://iptv-org.github.io/iptv/categories/auto.m3u',
    description: 'Canales de motor y automoción; pueden incluir contenido deportivo',
  ),
];
