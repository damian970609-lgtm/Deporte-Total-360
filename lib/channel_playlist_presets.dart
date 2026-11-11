/// Fuentes públicas de listas IPTV para el panel privado de Damián APK.
///
/// Las URLs son distintas entre sí. Algunas listas generales o regionales
/// pueden contener canales también presentes en otras fuentes; el catálogo
/// del servidor conserva el identificador de cada canal cuando está disponible.
const int maxChannelPlaylistSources = 100;
const String iptvOrgGlobalIndexPlaylistUrl =
    'https://iptv-org.github.io/iptv/index.m3u';
const String iptvOrgGlobalIndexPlaylistLabel =
    'IPTV-org · Índice global (más de 11.000 canales)';

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
    label: iptvOrgGlobalIndexPlaylistLabel,
    url: iptvOrgGlobalIndexPlaylistUrl,
    description: 'Índice maestro global de IPTV-org con más de 11.000 canales públicos de múltiples países; el importador los procesa por lotes',
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
    url: 'https://raw.githubusercontent.com/teleonline/listas/main/tv.m3u8',
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
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Estados Unidos',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/us.m3u',
    description: 'Lista pública verificada de canales del país Estados Unidos; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Canadá',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ca.m3u',
    description: 'Lista pública verificada de canales del país Canadá; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Australia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/au.m3u',
    description: 'Lista pública verificada de canales del país Australia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Brasil',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/br.m3u',
    description: 'Lista pública verificada de canales del país Brasil; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Chile',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/cl.m3u',
    description: 'Lista pública verificada de canales del país Chile; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Colombia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/co.m3u',
    description: 'Lista pública verificada de canales del país Colombia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Costa Rica',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/cr.m3u',
    description: 'Lista pública verificada de canales del país Costa Rica; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · República Dominicana',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/do.m3u',
    description: 'Lista pública verificada de canales del país República Dominicana; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Bolivia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/bo.m3u',
    description: 'Lista pública verificada de canales del país Bolivia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Venezuela',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ve.m3u',
    description: 'Lista pública verificada de canales del país Venezuela; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Perú',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/pe.m3u',
    description: 'Lista pública verificada de canales del país Perú; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Paraguay',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/py.m3u',
    description: 'Lista pública verificada de canales del país Paraguay; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Uruguay',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/uy.m3u',
    description: 'Lista pública verificada de canales del país Uruguay; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Ecuador',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ec.m3u',
    description: 'Lista pública verificada de canales del país Ecuador; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Panamá',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/pa.m3u',
    description: 'Lista pública verificada de canales del país Panamá; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Guatemala',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/gt.m3u',
    description: 'Lista pública verificada de canales del país Guatemala; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Honduras',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/hn.m3u',
    description: 'Lista pública verificada de canales del país Honduras; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Nicaragua',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ni.m3u',
    description: 'Lista pública verificada de canales del país Nicaragua; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · El Salvador',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/sv.m3u',
    description: 'Lista pública verificada de canales del país El Salvador; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Belice',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/bz.m3u',
    description: 'Lista pública verificada de canales del país Belice; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Guyana',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/gy.m3u',
    description: 'Lista pública verificada de canales del país Guyana; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Barbados',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/bb.m3u',
    description: 'Lista pública verificada de canales del país Barbados; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Jamaica',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/jm.m3u',
    description: 'Lista pública verificada de canales del país Jamaica; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Trinidad y Tobago',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/tt.m3u',
    description: 'Lista pública verificada de canales del país Trinidad y Tobago; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Cuba',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/cu.m3u',
    description: 'Lista pública verificada de canales del país Cuba; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Haití',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ht.m3u',
    description: 'Lista pública verificada de canales del país Haití; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Guayana Francesa',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/gf.m3u',
    description: 'Lista pública verificada de canales del país Guayana Francesa; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Surinam',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/sr.m3u',
    description: 'Lista pública verificada de canales del país Surinam; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Francia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/fr.m3u',
    description: 'Lista pública verificada de canales del país Francia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Alemania',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/de.m3u',
    description: 'Lista pública verificada de canales del país Alemania; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Italia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/it.m3u',
    description: 'Lista pública verificada de canales del país Italia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Portugal',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/pt.m3u',
    description: 'Lista pública verificada de canales del país Portugal; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Países Bajos',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/nl.m3u',
    description: 'Lista pública verificada de canales del país Países Bajos; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Bélgica',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/be.m3u',
    description: 'Lista pública verificada de canales del país Bélgica; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Suiza',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ch.m3u',
    description: 'Lista pública verificada de canales del país Suiza; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Noruega',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/no.m3u',
    description: 'Lista pública verificada de canales del país Noruega; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Suecia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/se.m3u',
    description: 'Lista pública verificada de canales del país Suecia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Dinamarca',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/dk.m3u',
    description: 'Lista pública verificada de canales del país Dinamarca; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Finlandia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/fi.m3u',
    description: 'Lista pública verificada de canales del país Finlandia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Polonia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/pl.m3u',
    description: 'Lista pública verificada de canales del país Polonia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Chequia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/cz.m3u',
    description: 'Lista pública verificada de canales del país Chequia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Rumanía',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ro.m3u',
    description: 'Lista pública verificada de canales del país Rumanía; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Hungría',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/hu.m3u',
    description: 'Lista pública verificada de canales del país Hungría; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Grecia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/gr.m3u',
    description: 'Lista pública verificada de canales del país Grecia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Irlanda',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ie.m3u',
    description: 'Lista pública verificada de canales del país Irlanda; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Reino Unido',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/uk.m3u',
    description: 'Lista pública verificada de canales del país Reino Unido; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Estonia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ee.m3u',
    description: 'Lista pública verificada de canales del país Estonia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Letonia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/lv.m3u',
    description: 'Lista pública verificada de canales del país Letonia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Lituania',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/lt.m3u',
    description: 'Lista pública verificada de canales del país Lituania; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Eslovaquia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/sk.m3u',
    description: 'Lista pública verificada de canales del país Eslovaquia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Eslovenia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/si.m3u',
    description: 'Lista pública verificada de canales del país Eslovenia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Croacia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/hr.m3u',
    description: 'Lista pública verificada de canales del país Croacia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Bosnia y Herzegovina',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ba.m3u',
    description: 'Lista pública verificada de canales del país Bosnia y Herzegovina; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Serbia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/rs.m3u',
    description: 'Lista pública verificada de canales del país Serbia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Rusia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ru.m3u',
    description: 'Lista pública verificada de canales del país Rusia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Ucrania',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ua.m3u',
    description: 'Lista pública verificada de canales del país Ucrania; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Turquía',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/tr.m3u',
    description: 'Lista pública verificada de canales del país Turquía; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Israel',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/il.m3u',
    description: 'Lista pública verificada de canales del país Israel; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Jordania',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/jo.m3u',
    description: 'Lista pública verificada de canales del país Jordania; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Arabia Saudita',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/sa.m3u',
    description: 'Lista pública verificada de canales del país Arabia Saudita; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Emiratos Árabes Unidos',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ae.m3u',
    description: 'Lista pública verificada de canales del país Emiratos Árabes Unidos; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Catar',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/qa.m3u',
    description: 'Lista pública verificada de canales del país Catar; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Kuwait',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/kw.m3u',
    description: 'Lista pública verificada de canales del país Kuwait; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Baréin',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/bh.m3u',
    description: 'Lista pública verificada de canales del país Baréin; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Omán',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/om.m3u',
    description: 'Lista pública verificada de canales del país Omán; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Marruecos',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ma.m3u',
    description: 'Lista pública verificada de canales del país Marruecos; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Egipto',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/eg.m3u',
    description: 'Lista pública verificada de canales del país Egipto; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Nigeria',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ng.m3u',
    description: 'Lista pública verificada de canales del país Nigeria; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Ghana',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/gh.m3u',
    description: 'Lista pública verificada de canales del país Ghana; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Kenia',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/ke.m3u',
    description: 'Lista pública verificada de canales del país Kenia; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Sudáfrica',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/za.m3u',
    description: 'Lista pública verificada de canales del país Sudáfrica; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Pakistán',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/pk.m3u',
    description: 'Lista pública verificada de canales del país Pakistán; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · India',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/in.m3u',
    description: 'Lista pública verificada de canales del país India; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Bangladés',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/bd.m3u',
    description: 'Lista pública verificada de canales del país Bangladés; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Sri Lanka',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/lk.m3u',
    description: 'Lista pública verificada de canales del país Sri Lanka; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
  ),
  ChannelPlaylistPreset(
    label: 'IPTV Validated · Japón',
    url: 'https://raw.githubusercontent.com/AdeelWajid/iptv_validated_list/main/playlists/countries/jp.m3u',
    description: 'Lista pública verificada de canales del país Japón; se importan todos los canales multimedia compatibles y se clasifican los deportivos para publicación voluntaria',
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
