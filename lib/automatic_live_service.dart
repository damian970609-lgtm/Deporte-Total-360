import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import 'live_media_format.dart';
import 'sports_api_service.dart';

const String _playlistUrlKey = 'dt360_auto_live_playlist_url_v1';
const String _playlistTextKey = 'dt360_auto_live_playlist_text_v1';
const String _playlistTextsKey = 'dt360_auto_live_playlist_texts_v2';
const String _epgUrlKey = 'dt360_auto_live_epg_url_v1';
const String _authorizedKey = 'dt360_auto_live_authorized_v1';
const String _defaultSourcesMigratedKey = 'dt360_auto_live_default_sources_migrated_v1';

/// Normaliza imágenes de MARCA: admite URL HTTPS absolutas, protocol-relative
/// y rutas relativas del mismo sitio. Nunca permite esquemas no HTTPS ni
/// URLs con credenciales.
String _marcaImageUrl(dynamic value) {
  if (value is List) {
    for (final item in value) {
      final candidate = _marcaImageUrl(item);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }
  if (value is Map) {
    for (final key in <String>[
      'url', 'contentUrl', 'thumbnailUrl', 'src', 'image',
      'logo', 'crest', 'badge', 'photo', 'picture', 'avatar', 'href',
    ]) {
      final candidate = _marcaImageUrl(value[key]);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }
  if (value is! String) return '';
  final raw = value.trim();
  if (raw.isEmpty || raw.toLowerCase().startsWith('data:')) return '';
  try {
    var uri = Uri.parse(raw.startsWith('//') ? 'https:$raw' : raw);
    if (!uri.hasScheme) {
      uri = Uri.parse('https://www.marca.com/').resolveUri(uri);
    } else if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }
    if (uri.scheme != 'https' || !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) return '';
    return uri.toString();
  } catch (_) {
    return '';
  }
}

/// Catálogos globales y una lista adicional de emisoras deportivas públicas.
/// La presencia en un índice no sustituye la comprobación de derechos del emisor.
const String legacyDefaultAutoLivePlaylistUrls =
    'https://dearbulut.github.io/iptv/playlists/category/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/online.m3u\n'
    'https://iptv-org.github.io/iptv/categories/sports.m3u';
const String legacyDefaultAutoLiveEpgUrl =
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz';

// Snapshot de los valores predeterminados de la versión anterior. Se usa
// para ampliar las instalaciones ya existentes sin borrar fuentes personales.
const String previousDefaultAutoLivePlaylistUrls =
    'https://teleonline.github.io/listas/tv.m3u8\n'
    'https://iptv-org.github.io/iptv/languages/spa.m3u\n'
    'https://iptv-org.github.io/iptv/countries/es.m3u\n'
    'https://iptv-org.github.io/iptv/countries/mx.m3u\n'
    'https://iptv-org.github.io/iptv/countries/ar.m3u\n'
    'https://iptv-org.github.io/iptv/regions/hispam.m3u\n'
    'https://iptv-org.github.io/iptv/regions/lac.m3u\n'
    'https://iptv-org.github.io/iptv/categories/sports.m3u\n'
    'https://raw.githubusercontent.com/freecasthub/public-iptv/main/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/category/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/online.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/best.m3u';
const String previousDefaultAutoLiveEpgUrl =
    'https://iptv-epg.org/files/epg-es.xml\n'
    'https://iptv-epg.org/files/epg-ar.xml\n'
    'https://iptv-epg.org/files/epg-mx.xml\n'
    'https://iptv-epg.org/files/epg-co.xml\n'
    'https://iptv-epg.org/files/epg-ve.xml\n'
    'https://iptv-epg.org/files/epg-cl.xml\n'
    'https://iptv-epg.org/files/epg-pe.xml\n'
    'https://iptv-epg.org/files/epg-uy.xml\n'
    'https://iptv-epg.org/files/epg-py.xml\n'
    'https://iptv-epg.org/files/epg-bo.xml\n'
    'https://iptv-epg.org/files/epg-cr.xml\n'
    'https://iptv-epg.org/files/epg-gt.xml\n'
    'https://iptv-epg.org/files/epg-hn.xml\n'
    'https://iptv-epg.org/files/epg-ni.xml\n'
    'https://iptv-epg.org/files/epg-pa.xml\n'
    'https://iptv-epg.org/files/epg-cw.xml\n'
    'https://iptv-epg.org/files/epg-jm.xml\n'
    'https://iptv-epg.org/files/epg-br.xml\n'
    'https://raw.githubusercontent.com/teleonline/listas/main/epg.xml.gz\n'
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz';

// Listas públicas: deportes y canales abiertos de repositorios GitHub
// mantenidos por comunidad, conservando las fuentes regionales en español.
const String defaultAutoLivePlaylistUrls =
    'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8\n' +
    previousDefaultAutoLivePlaylistUrls +
    '\nhttps://biskyt.github.io/legalFreeIPTVplaylist/live.m3u';

// EPG regional en español y Caribe. Los XML se procesan en lotes limitados.
const String defaultAutoLiveEpgUrl =
    previousDefaultAutoLiveEpgUrl + '\n'
    'https://iptv-epg.org/files/epg-do.xml\n'
    'https://iptv-epg.org/files/epg-sv.xml\n'
    'https://epgshare01.online/epgshare01/epg_ripper_ES1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_AR1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_MX1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_CO1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_CL1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_PE1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_DO1.xml.gz\n'
    'https://epgshare01.online/epgshare01/epg_ripper_BR1.xml.gz';

List<String> _splitPlaylistUrls(String value) => value
    .split(RegExp(r'[\r\n;]+'))
    .map((url) => url.trim())
    .where((url) => url.isNotEmpty)
    .toList(growable: false);

bool isSafeHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasAuthority &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.userInfo.isEmpty;
}

bool isDirectPlayableStream(String value) =>
    liveMediaFormatForUrl(value) != null;

bool _isLegacyOttfoxWebUrl(String value) {
  final host = Uri.tryParse(value.trim())?.host.toLowerCase() ?? '';
  return host == 'ottfox.net' || host.endsWith('.ottfox.net');
}

class AutoLiveSettings {
  const AutoLiveSettings({
    required this.playlistUrl,
    required this.epgUrl,
    required this.authorizationConfirmed,
    this.playlistText = '',
    this.playlistTexts = const <String>[],
  });
  final String playlistUrl;
  final String epgUrl;
  final bool authorizationConfirmed;
  /// M3U local copiada o exportada desde OTTFOX (compatibilidad anterior).
  final String playlistText;
  /// Biblioteca local de OTTFOX, guardada como listas independientes.
  final List<String> playlistTexts;

  List<String> get localPlaylistTexts => <String>{
    ...playlistTexts.map((item) => item.trim()).where((item) => item.isNotEmpty),
    if (playlistText.trim().isNotEmpty) playlistText.trim(),
  }.toList(growable: false);

  List<String> get playlistUrls => _splitPlaylistUrls(playlistUrl);
  List<String> get epgUrls => _splitPlaylistUrls(epgUrl);

  // Las fuentes públicas incluidas se cargan automáticamente.
  bool get isConfigured =>
      playlistUrls.isNotEmpty &&
      playlistUrls.every(isSafeHttpUrl) &&
      epgUrls.isNotEmpty &&
      epgUrls.every(isSafeHttpUrl);

  static Future<AutoLiveSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var playlist = prefs.getString(_playlistUrlKey) ?? defaultAutoLivePlaylistUrls;
    var epg = prefs.getString(_epgUrlKey) ?? defaultAutoLiveEpgUrl;
    final playlistText = prefs.getString(_playlistTextKey) ?? '';
    final playlistTexts = prefs.getStringList(_playlistTextsKey) ?? <String>[];

    // Actualiza una sola vez las instalaciones anteriores: incorpora las
    // fuentes públicas incluidas, conserva URLs personales y descarta la
    // dirección de la antigua página OTTFOX (no era una lista M3U).
    final sourcesMigrated = prefs.getBool(_defaultSourcesMigratedKey) ?? false;
    if (!sourcesMigrated) {
      final defaults = _splitPlaylistUrls(defaultAutoLivePlaylistUrls);
      final savedPlaylists = _splitPlaylistUrls(playlist)
          .where((url) => isSafeHttpUrl(url) && !_isLegacyOttfoxWebUrl(url));
      final prioritySources = defaults.where(
        (url) => url.contains('raw.githubusercontent.com/Free-TV/IPTV/'),
      );
      playlist = <String>{
        ...prioritySources,
        ...savedPlaylists,
        ...defaults,
      }.join('\n');

      final savedEpg = _splitPlaylistUrls(epg)
          .where((url) => isSafeHttpUrl(url) && !_isLegacyOttfoxWebUrl(url));
      epg = <String>{
        ..._splitPlaylistUrls(defaultAutoLiveEpgUrl),
        ...savedEpg,
      }.join('\n');

      await prefs.setString(_playlistUrlKey, playlist);
      await prefs.setString(_epgUrlKey, epg);
      await prefs.setBool(_defaultSourcesMigratedKey, true);
    }

    // Elimina páginas web e URLs inválidas, pero mantiene todas las fuentes
    // M3U/EPG personales que sí sean direcciones HTTP/HTTPS.
    final safePlaylists = _splitPlaylistUrls(playlist)
        .where((url) => isSafeHttpUrl(url) && !_isLegacyOttfoxWebUrl(url))
        .toList(growable: false);
    if (safePlaylists.isEmpty) {
      playlist = defaultAutoLivePlaylistUrls;
      await prefs.setString(_playlistUrlKey, playlist);
    } else if (safePlaylists.length != _splitPlaylistUrls(playlist).length) {
      playlist = safePlaylists.join('\n');
      await prefs.setString(_playlistUrlKey, playlist);
    }

    final safeEpg = _splitPlaylistUrls(epg)
        .where((url) => isSafeHttpUrl(url) && !_isLegacyOttfoxWebUrl(url))
        .toList(growable: false);
    if (safeEpg.isEmpty) {
      epg = defaultAutoLiveEpgUrl;
      await prefs.setString(_epgUrlKey, epg);
    } else if (safeEpg.length != _splitPlaylistUrls(epg).length) {
      epg = safeEpg.join('\n');
      await prefs.setString(_epgUrlKey, epg);
    }

    return AutoLiveSettings(
      playlistUrl: playlist,
      epgUrl: epg,
      authorizationConfirmed: true,
      playlistText: playlistText,
      playlistTexts: playlistTexts,
    );
  }

  static Future<void> save({
    required String playlistUrl,
    required String epgUrl,
    required bool authorizationConfirmed,
    String? playlistText,
    List<String>? playlistTexts,
  }) async {
    final playlist = _splitPlaylistUrls(playlistUrl).join('\n');
    final epg = _splitPlaylistUrls(epgUrl).join('\n');
    final playlistUrls = _splitPlaylistUrls(playlist);
    final epgUrls = _splitPlaylistUrls(epg);
    if (playlistUrls.isEmpty ||
        !playlistUrls.every(isSafeHttpUrl) ||
        epgUrls.isEmpty ||
        !epgUrls.every(isSafeHttpUrl)) {
      throw const FormatException('Cada lista M3U y cada guía EPG deben tener una dirección HTTP o HTTPS válida.');
    }
    final localPlaylist = playlistText?.trim();
    final localPlaylists = <String>{
      if (playlistTexts != null)
        ...playlistTexts.map((item) => item.trim()).where((item) => item.isNotEmpty),
      if (localPlaylist != null && localPlaylist.isNotEmpty) localPlaylist,
    }.toList(growable: false);
    if (localPlaylists.any((item) => item.length > 3 * 1024 * 1024)) {
      throw const FormatException('Una lista OTTFOX supera el límite de 3 MB. Divide esa lista antes de importarla.');
    }
    final totalLocalBytes = localPlaylists.fold<int>(0, (total, item) => total + utf8.encode(item).length);
    if (totalLocalBytes > 12 * 1024 * 1024) {
      throw const FormatException('La biblioteca OTTFOX supera el límite local de 12 MB. Divide o reduce las listas para importarlas por partes.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistUrlKey, playlist);
    await prefs.setString(_epgUrlKey, epg);
    if (playlistTexts != null || localPlaylist != null) {
      if (localPlaylists.isEmpty) {
        await prefs.remove(_playlistTextsKey);
      } else {
        await prefs.setStringList(_playlistTextsKey, localPlaylists);
      }
      // Las listas nuevas se guardan en la colección v2 para permitir varias
      // listas sin sobrescribir el M3U importado anteriormente.
      await prefs.setString(_playlistTextKey, '');
    }
    await prefs.setBool(_authorizedKey, true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // Valores vacíos evitan que los valores predeterminados vuelvan a aparecer
    // inmediatamente después de que el usuario pulse Borrar.
    await prefs.setString(_playlistUrlKey, '');
    await prefs.setString(_epgUrlKey, '');
    await prefs.setString(_playlistTextKey, '');
    await prefs.remove(_playlistTextsKey);
    await prefs.setBool(_authorizedKey, false);
  }
}

class SportsAgendaParticipant {
  const SportsAgendaParticipant({
    required this.name,
    this.imageUrl = '',
    this.country = '',
    this.role = '',
  });

  final String name;
  final String imageUrl;
  final String country;
  final String role;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'imageUrl': imageUrl,
    'country': country,
    'role': role,
  };

  static SportsAgendaParticipant? fromJson(dynamic value) {
    if (value is String) {
      final name = value.trim();
      return name.isEmpty ? null : SportsAgendaParticipant(name: name);
    }
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final name = (row['name'] ?? row['title'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final imageUrl = _marcaImageUrl(
      row['imageUrl'] ?? row['logo'] ?? row['image'] ??
      row['thumbnailUrl'] ?? row['photo'] ?? row['picture'] ?? row['avatar'],
    );
    return SportsAgendaParticipant(
      name: name,
      imageUrl: imageUrl,
      country: (row['country'] ?? row['nationality'] ?? '').toString().trim(),
      role: (row['role'] ?? '').toString().trim(),
    );
  }
}

class SportsAgendaEvent {
  const SportsAgendaEvent({
    required this.id,
    required this.title,
    required this.sport,
    required this.startsAt,
    required this.detailUrl,
    this.competition = '',
    this.homeTeam = '',
    this.awayTeam = '',
    this.homeTeamLogo = '',
    this.awayTeamLogo = '',
    this.participants = const <SportsAgendaParticipant>[],
    this.imageUrl = '',
    this.venue = '',
    this.status = 'scheduled',
    this.statusLabel = '',
    this.homeScore = '',
    this.awayScore = '',
    this.providerLeagueId,
    this.providerSeasonId,
    this.providerSeriesId,
    this.endsAt,
  });
  final String id;
  final String title;
  final String sport;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamLogo;
  final String awayTeamLogo;
  final List<SportsAgendaParticipant> participants;
  final String imageUrl;
  final String venue;
  final String status;
  final String statusLabel;
  final String homeScore;
  final String awayScore;
  final int? providerLeagueId;
  final int? providerSeasonId;
  final int? providerSeriesId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String detailUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'sport': sport,
    'competition': competition,
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'homeTeamLogo': homeTeamLogo,
    'awayTeamLogo': awayTeamLogo,
    'participants': participants.map((item) => item.toJson()).toList(),
    'imageUrl': imageUrl,
    'venue': venue,
    'status': status,
    'statusLabel': statusLabel,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'providerLeagueId': providerLeagueId,
    'providerSeasonId': providerSeasonId,
    'providerSeriesId': providerSeriesId,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'detailUrl': detailUrl,
  };

  static SportsAgendaEvent? fromJson(dynamic value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final id = (row['id'] ?? '').toString().trim();
    final title = (row['title'] ?? '').toString().trim();
    final startsAt = DateTime.tryParse((row['startsAt'] ?? '').toString());
    final detailUrl = (row['detailUrl'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty || startsAt == null ||
        !isSafeHttpUrl(detailUrl)) return null;
    final end = DateTime.tryParse((row['endsAt'] ?? '').toString());
    final rawParticipants = row['participants'];
    final participants = rawParticipants is List
        ? rawParticipants
            .map(SportsAgendaParticipant.fromJson)
            .whereType<SportsAgendaParticipant>()
            .toList(growable: false)
        : <SportsAgendaParticipant>[];
    final homeTeam = (row['homeTeam'] ?? '').toString();
    final awayTeam = (row['awayTeam'] ?? '').toString();
    final homeLogo = _marcaImageUrl(
      row['homeTeamLogo'] ?? row['homeTeamLogoUrl'] ?? row['homeLogo'],
    );
    final awayLogo = _marcaImageUrl(
      row['awayTeamLogo'] ?? row['awayTeamLogoUrl'] ?? row['awayLogo'],
    );
    final eventImage = _marcaImageUrl(
      row['imageUrl'] ?? row['image'] ?? row['thumbnailUrl'] ?? row['photo'],
    );
    String participantImage(String name) => participants
        .where((item) => item.name.toLowerCase() == name.toLowerCase())
        .map((item) => item.imageUrl)
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    return SportsAgendaEvent(
      id: id,
      title: title,
      sport: (row['sport'] ?? 'Deporte').toString(),
      competition: (row['competition'] ?? '').toString(),
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeTeamLogo: homeLogo.isNotEmpty ? homeLogo : participantImage(homeTeam),
      awayTeamLogo: awayLogo.isNotEmpty ? awayLogo : participantImage(awayTeam),
      participants: participants,
      imageUrl: eventImage,
      venue: (row['venue'] ?? '').toString(),
      status: (row['status'] ?? 'scheduled').toString(),
      statusLabel: (row['statusLabel'] ?? '').toString(),
      homeScore: (row['homeScore'] ?? '').toString(),
      awayScore: (row['awayScore'] ?? '').toString(),
      providerLeagueId: int.tryParse((row['providerLeagueId'] ?? '').toString()),
      providerSeasonId: int.tryParse((row['providerSeasonId'] ?? '').toString()),
      providerSeriesId: int.tryParse((row['providerSeriesId'] ?? '').toString()),
      startsAt: startsAt.toLocal(),
      endsAt: end?.toLocal(),
      detailUrl: detailUrl,
    );
  }
}

class SportsAgendaStore {
  static const String _key = 'dt360_sports_agenda_events_v2';

  /// Sustituye la captura anterior por el contenido visible más reciente.
  /// Así los eventos retirados de la agenda no quedan programados.
  static Future<void> save(List<SportsAgendaEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final unique = <String, SportsAgendaEvent>{
      for (final event in events) event.id: event,
    };
    final cutoff = DateTime.now().subtract(const Duration(hours: 4));
    unique.removeWhere((id, event) {
      final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      return end.isBefore(cutoff);
    });
    await prefs.setString(
      _key,
      jsonEncode(unique.values.map((event) => event.toJson()).toList()),
    );
  }

  static Future<List<SportsAgendaEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <SportsAgendaEvent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SportsAgendaEvent>[];
      return decoded.map(SportsAgendaEvent.fromJson)
          .whereType<SportsAgendaEvent>().toList(growable: false);
    } catch (_) { return <SportsAgendaEvent>[]; }
  }
}

class M3uChannel {
  const M3uChannel({
    required this.name,
    required this.url,
    this.tvgId = '',
    this.tvgName = '',
    this.group = '',
    this.logo = '',
    this.language = '',
    this.country = '',
    this.sourceUrl = '',
  });
  final String name;
  final String url;
  final String sourceUrl;
  final String tvgId;
  final String tvgName;
  final String group;
  final String logo;
  final String language;
  final String country;

  /// 2 = español; 0 = cualquier idioma como respaldo.
  int get languagePriority {
    final metadata = AutomaticLiveService.normalizeText(
      '$language $country $group $name $tvgName',
    );
    const spanishMarkers = <String>[
      'spanish', 'espanol', 'castellano', 'espana', 'spain',
      'mexico', 'argentina', 'colombia', 'venezuela', 'chile',
      'peru', 'uruguay', 'paraguay', 'bolivia', 'ecuador',
      'costa rica', 'guatemala', 'honduras', 'nicaragua',
      'panama', 'dominicana', 'puerto rico',
      'teledeporte', 'esport 3', 'etb deportes',
      'real madrid tv', 'betis tv',
    ];
    if (spanishMarkers.any(metadata.contains) ||
        RegExp(r'(^| )(es|spa)( |$)').hasMatch(metadata)) {
      return 2;
    }
    return 0;
  }
}

class XmltvProgramme {
  const XmltvProgramme({
    required this.channelId, required this.title,
    required this.startsAt, required this.endsAt,
    this.channelName = '',
  });
  final String channelId;
  final String channelName;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
}

class ScheduledLiveSource {
  const ScheduledLiveSource({
    required this.channelName, required this.url,
    required this.programmeTitle, required this.programmeEndsAt,
    required this.qualityScore,
    this.languagePriority = 0,
    this.available = false,
  });
  final String channelName;
  final String url;
  final String programmeTitle;
  final DateTime programmeEndsAt;
  final int qualityScore;
  final int languagePriority;
  final bool available;
}

class ScheduledLiveEvent {
  const ScheduledLiveEvent({
    required this.event, required this.sources, required this.removeAt,
  });
  final SportsAgendaEvent event;
  final List<ScheduledLiveSource> sources;
  final DateTime removeAt;
}

class AutoLiveCatalog {
  const AutoLiveCatalog({required this.channels, required this.programmes});
  final List<M3uChannel> channels;
  final List<XmltvProgramme> programmes;
}

class AutomaticLiveService {
  AutomaticLiveService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
  AutoLiveCatalog? _cachedCatalog;
  DateTime? _cachedAt;
  String? _cachedPlaylist;
  String? _cachedPlaylistText;
  String? _cachedEpg;
  final Map<String, ({bool available, int quality, DateTime checkedAt})> _probeCache =
      <String, ({bool available, int quality, DateTime checkedAt})>{};

  /// Lee las asignaciones compartidas por el planificador Cloudflare.
  /// Devuelve null solo cuando el endpoint todavía no está disponible; una
  /// respuesta válida sin eventos devuelve una lista vacía y evita reutilizar
  /// partidos antiguos del almacenamiento local.
  Future<List<ScheduledLiveEvent>?> fetchPublishedSchedule() async {
    final base = SportsApiService.normalizeBaseUrl(sportsApiBaseUrl.value);
    if (base == null) return null;
    final uri = Uri.parse('$base/api/live/auto/schedule');
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode == 404 || response.statusCode == 503) {
        return null;
      }
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final status = (decoded['status'] ?? '').toString();
      if (status != 'ok' && status != 'stale') return null;
      final rows = decoded['events'];
      if (rows is! List) return null;

      final now = DateTime.now();
      final result = <ScheduledLiveEvent>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final eventRaw = row['event'];
        if (eventRaw is! Map) continue;
        final eventData = Map<String, dynamic>.from(eventRaw);
        final startsAt = DateTime.tryParse(
          (eventData['startsAt'] ?? '').toString(),
        );
        final endsAt = DateTime.tryParse(
          (eventData['endsAt'] ?? '').toString(),
        );
        final id = (eventData['id'] ?? '').toString().trim();
        final title = (eventData['title'] ?? '').toString().trim();
        if (id.isEmpty || title.isEmpty || startsAt == null) continue;
        final detailUrl = (eventData['detailUrl'] ?? '').toString().trim();
        final rawParticipants = eventData['participants'];
        final participants = rawParticipants is List
            ? rawParticipants
                .map(SportsAgendaParticipant.fromJson)
                .whereType<SportsAgendaParticipant>()
                .toList(growable: false)
            : <SportsAgendaParticipant>[];
        String safeLogo(dynamic value) => _marcaImageUrl(value);
        final homeTeam = (eventData['homeTeam'] ?? '').toString();
        final awayTeam = (eventData['awayTeam'] ?? '').toString();
        String participantLogo(String name) => participants
            .where((item) => item.name.toLowerCase() == name.toLowerCase())
            .map((item) => item.imageUrl)
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');
        final event = SportsAgendaEvent(
          id: id,
          title: title,
          sport: (eventData['sport'] ?? 'Deporte').toString(),
          competition: (eventData['competition'] ?? '').toString(),
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          homeTeamLogo: safeLogo(
            eventData['homeTeamLogo'] ??
            eventData['homeTeamLogoUrl'] ??
            eventData['homeLogo'],
          ).isNotEmpty
              ? safeLogo(
                  eventData['homeTeamLogo'] ??
                  eventData['homeTeamLogoUrl'] ??
                  eventData['homeLogo'],
                )
              : participantLogo(homeTeam),
          awayTeamLogo: safeLogo(
            eventData['awayTeamLogo'] ??
            eventData['awayTeamLogoUrl'] ??
            eventData['awayLogo'],
          ).isNotEmpty
              ? safeLogo(
                  eventData['awayTeamLogo'] ??
                  eventData['awayTeamLogoUrl'] ??
                  eventData['awayLogo'],
                )
              : participantLogo(awayTeam),
          participants: participants,
          imageUrl: safeLogo(
            eventData['imageUrl'] ??
            eventData['image'] ??
            eventData['thumbnailUrl'] ??
            eventData['photo'],
          ),
          venue: (eventData['venue'] ?? '').toString(),
          status: (eventData['status'] ?? 'scheduled').toString(),
          statusLabel: (eventData['statusLabel'] ?? '').toString(),
          homeScore: (eventData['homeScore'] ?? '').toString(),
          awayScore: (eventData['awayScore'] ?? '').toString(),
          providerLeagueId: int.tryParse((eventData['providerLeagueId'] ?? '').toString()),
          providerSeasonId: int.tryParse((eventData['providerSeasonId'] ?? '').toString()),
          providerSeriesId: int.tryParse((eventData['providerSeriesId'] ?? '').toString()),
          startsAt: startsAt.toLocal(),
          endsAt: endsAt?.toLocal(),
          detailUrl: isSafeHttpUrl(detailUrl)
              ? detailUrl
              : 'https://www.marca.com/programacion-tv.html',
        );

        final removeAt = DateTime.tryParse(
          (row['removeAt'] ?? '').toString(),
        ) ?? endsAt ?? startsAt.add(const Duration(hours: 3));
        if (!removeAt.isAfter(now)) continue;

        final sourcesRaw = row['sources'];
        final sources = <ScheduledLiveSource>[];
        if (sourcesRaw is List) {
          for (final sourceValue in sourcesRaw) {
            if (sourceValue is! Map) continue;
            final source = Map<String, dynamic>.from(sourceValue);
            final url = (source['url'] ?? '').toString().trim();
            final programmeEnd = DateTime.tryParse(
              (source['programmeEndsAt'] ?? '').toString(),
            ) ?? removeAt;
            if (source['available'] != true || !isDirectPlayableStream(url)) {
              continue;
            }
            sources.add(ScheduledLiveSource(
              channelName: (source['channelName'] ?? '').toString(),
              url: url,
              programmeTitle: (source['programmeTitle'] ?? '').toString(),
              programmeEndsAt: programmeEnd.toLocal(),
              qualityScore: int.tryParse(
                (source['qualityScore'] ?? 0).toString(),
              ) ?? 0,
              languagePriority: int.tryParse(
                (source['languagePriority'] ?? 0).toString(),
              ) ?? 0,
              available: true,
            ));
          }
        }
        result.add(ScheduledLiveEvent(
          event: event,
          sources: sources,
          removeAt: removeAt.toLocal(),
        ));
      }
      result.sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
      return result;
    } catch (_) {
      // El cliente puede seguir usando la búsqueda local si el Worker está
      // temporalmente inaccesible o todavía no tiene instalado el cron nuevo.
      return null;
    }
  }

  Future<AutoLiveCatalog> loadCatalog({
    required String playlistUrl,
    required String epgUrl,
    String playlistText = '',
    List<String> playlistTexts = const <String>[],
    bool forceRefresh = false,
    int downloadBatchSize = 2,
    Duration batchPause = const Duration(milliseconds: 160),
    int maxPlaylistBytes = 8 * 1024 * 1024,
    int maxEpgBytes = 12 * 1024 * 1024,
    void Function(String phase, int completed, int total)? onProgress,
    void Function(List<M3uChannel> channels)? onChannelsLoaded,
    void Function(String url, Object error)? onSourceError,
  }) async {
    final playlistUrls = _splitPlaylistUrls(playlistUrl);
    final epgUrls = _splitPlaylistUrls(epgUrl);
    final localPlaylistTexts = <String>{
      if (playlistText.trim().isNotEmpty) playlistText.trim(),
      ...playlistTexts.map((item) => item.trim()).where((item) => item.isNotEmpty),
    }.toList(growable: false);
    final localPlaylistCacheKey = jsonEncode(localPlaylistTexts);
    if ((playlistUrls.isEmpty && localPlaylistTexts.isEmpty) ||
        !playlistUrls.every(isSafeHttpUrl) ||
        !epgUrls.every(isSafeHttpUrl)) {
      throw const FormatException('Configura al menos una lista M3U y utiliza direcciones HTTP o HTTPS válidas para las guías EPG.');
    }
    final int effectiveBatchSize = downloadBatchSize.clamp(1, 4).toInt();
    final playlistCacheKey = playlistUrls.join('\n');
    final epgCacheKey = epgUrls.join('\n');
    final now = DateTime.now();
    final cached = _cachedCatalog;
    if (!forceRefresh && cached != null &&
        _cachedPlaylist == playlistCacheKey &&
        _cachedPlaylistText == localPlaylistCacheKey && _cachedEpg == epgCacheKey &&
        _cachedAt != null && now.difference(_cachedAt!) < const Duration(minutes: 5)) {
      return cached;
    }

    // Se descargan hasta cuatro listas a la vez. Los canales se publican
    // por lote antes de procesar EPG, para que la pantalla no espere a las guías.
    // El análisis M3U/XMLTV se ejecuta en isolates y no bloquea la interfaz.
    final channelsByUrl = <String, M3uChannel>{};
    final playlistFailures = <String>[];
    for (var localIndex = 0; localIndex < localPlaylistTexts.length; localIndex++) {
      final localText = localPlaylistTexts[localIndex];
      final sourceLabel = 'Lista local ${localIndex + 1}';
      try {
        if (localText.length > maxPlaylistBytes ||
            !localText.toUpperCase().startsWith('#EXTM3U')) {
          throw const FormatException('La entrada guardada no es M3U o supera el tamaño permitido.');
        }
        final localChannels = await Isolate.run(
          () => parseM3u(localText, sourceUrl: sourceLabel),
        );
        if (localChannels.isEmpty) {
          throw const FormatException('La M3U no contiene enlaces directos HLS, DASH, TS o MP4 compatibles.');
        }
        for (final channel in localChannels) {
          channelsByUrl.putIfAbsent(channel.url, () => channel);
        }
        onChannelsLoaded?.call(List<M3uChannel>.unmodifiable(channelsByUrl.values));
      } catch (error) {
        playlistFailures.add(sourceLabel);
        onSourceError?.call(sourceLabel, error);
      }
      onProgress?.call('LOCAL', localIndex + 1, localPlaylistTexts.length);
      if (batchPause > Duration.zero) await Future<void>.delayed(batchPause);
    }
    for (var batchStart = 0; batchStart < playlistUrls.length; batchStart += effectiveBatchSize) {
      final batch = playlistUrls.skip(batchStart).take(effectiveBatchSize).toList(growable: false);
      final playlistBodies = await Future.wait<String?>(
        batch.map((url) async {
          try {
            return await _downloadText(
              url,
              maxBytes: maxPlaylistBytes,
              timeout: const Duration(seconds: 12),
            );
          } catch (error) {
            playlistFailures.add(url);
            onSourceError?.call(url, error);
            return null;
          }
        }),
      );
      for (var index = 0; index < playlistBodies.length; index++) {
        final body = playlistBodies[index];
        if (body == null) continue;
        // Algunas M3U contienen rutas relativas; se resuelven contra la
        // dirección de la propia lista antes de pasar la URL al reproductor.
        final baseUri = Uri.tryParse(batch[index]);
        try {
          final parsedChannels = await Isolate.run(
            () => parseM3u(body, baseUri: baseUri, sourceUrl: batch[index]),
          );
          if (parsedChannels.isEmpty) {
            playlistFailures.add(batch[index]);
            onSourceError?.call(
              batch[index],
              const FormatException('La lista no contiene enlaces directos compatibles.'),
            );
            continue;
          }
          for (final channel in parsedChannels) {
            channelsByUrl.putIfAbsent(channel.url, () => channel);
          }
        } catch (error) {
          // Una lista dañada no impide continuar con las demás fuentes.
          playlistFailures.add(batch[index]);
          onSourceError?.call(batch[index], error);
        }
      }
      if (channelsByUrl.isNotEmpty) {
        onChannelsLoaded?.call(
          List<M3uChannel>.unmodifiable(channelsByUrl.values),
        );
      }
      onProgress?.call('M3U', batchStart + batch.length, playlistUrls.length);
      if (batchPause > Duration.zero) await Future<void>.delayed(batchPause);
    }
    final channels = channelsByUrl.values.toList(growable: false);
    if (channels.isEmpty) {
      final failedSources = playlistFailures.take(3).join(', ');
      throw FormatException(
        'No se pudo cargar ningún canal. Revisa las direcciones M3U, el acceso del proveedor o que incluyan enlaces HLS/DASH/TS/MP4 directos.'
        '${failedSources.isEmpty ? '' : ' Fuentes sin respuesta o sin enlaces compatibles: $failedSources'}',
      );
    }

    // Las listas M3U pueden explorarse aunque todavía no se haya añadido EPG.
    // Cuando existen guías, se fusionan en lotes; un fallo de una guía no
    // impide mostrar los canales importados correctamente.
    final programmesByKey = <String, XmltvProgramme>{};
    // XMLTV puede consumir bastante memoria. Se descarga por lotes pequeños
    // y cada documento se analiza fuera del hilo de interfaz.
    for (var batchStart = 0; batchStart < epgUrls.length; batchStart += effectiveBatchSize) {
      final batch = epgUrls.skip(batchStart).take(effectiveBatchSize).toList(growable: false);
      final bodies = await Future.wait<String?>(
        batch.map((url) async {
          try {
            return await _downloadText(
              url,
              maxBytes: maxEpgBytes,
              timeout: const Duration(seconds: 12),
            );
          } catch (_) {
            return null;
          }
        }),
      );
      for (final epgBody in bodies.whereType<String>()) {
        try {
          final parsedProgrammes = await Isolate.run(() => parseXmltv(epgBody));
          for (final programme in parsedProgrammes) {
            final key = <String>[
              programme.channelId.toLowerCase(),
              programme.title.toLowerCase().trim(),
              programme.startsAt.toUtc().toIso8601String(),
              programme.endsAt.toUtc().toIso8601String(),
            ].join('|');
            programmesByKey.putIfAbsent(key, () => programme);
          }
        } catch (_) {
          // Una guía inválida no interrumpe las siguientes fuentes.
        }
      }
      onProgress?.call('EPG', batchStart + batch.length, epgUrls.length);
      if (batchPause > Duration.zero) await Future<void>.delayed(batchPause);
    }
    final programmes = programmesByKey.values.toList(growable: false);
    final catalog = AutoLiveCatalog(channels: channels, programmes: programmes);
    _cachedCatalog = catalog;
    _cachedAt = now;
    _cachedPlaylist = playlistCacheKey;
    _cachedPlaylistText = localPlaylistCacheKey;
    _cachedEpg = epgCacheKey;
    return catalog;
  }

  Future<String> _downloadText(
    String value, {
    required int maxBytes,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final request = http.Request('GET', Uri.parse(value.trim()))
      ..headers['Accept'] = '*/*';
    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw HttpException('La fuente respondió HTTP ' + response.statusCode.toString() + '.');
    }
    final declaredLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if (declaredLength != null && declaredLength > maxBytes) {
      await response.stream.drain<void>();
      throw const FormatException('El archivo supera el tamaño máximo permitido.');
    }

    // Se limita el flujo mientras llega, sin descargar primero un XML gigante.
    final compressed = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream.timeout(timeout)) {
      received += chunk.length;
      if (received > maxBytes) {
        throw const FormatException('La descarga supera el tamaño máximo permitido.');
      }
      compressed.add(chunk);
    }
    final bytes = compressed.takeBytes();
    return Isolate.run(() async {
      try {
        List<int> decodedBytes = bytes;
        if (decodedBytes.length >= 2 &&
            decodedBytes[0] == 0x1f &&
            decodedBytes[1] == 0x8b) {
          final expanded = BytesBuilder(copy: false);
          var expandedLength = 0;
          await for (final chunk in gzip.decoder
              .bind(Stream<List<int>>.value(decodedBytes))) {
            expandedLength += chunk.length;
            if (expandedLength > maxBytes) {
              throw const FormatException(
                'El archivo descomprimido supera el límite permitido.',
              );
            }
            expanded.add(chunk);
          }
          decodedBytes = expanded.takeBytes();
        }
        final body = utf8.decode(decodedBytes, allowMalformed: true);
        if (body.trim().isEmpty) {
          throw const FormatException('La fuente está vacía.');
        }
        return body;
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException(
          'No se pudo descomprimir o decodificar la fuente.',
        );
      }
    });
  }

  static List<M3uChannel> parseM3u(
    String body, {
    Uri? baseUri,
    String sourceUrl = '',
  }) {
    final lines = body.replaceAll('\r', '').split('\n');
    final result = <M3uChannel>[];
    Map<String, String>? pending;
    var pendingName = '';
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        final metadata = comma >= 0 ? line.substring(0, comma) : line;
        pendingName = comma >= 0 ? line.substring(comma + 1).trim() : '';
        final attributes = <String, String>{};
        for (final match in RegExp(r'([\w-]+)="([^"]*)"').allMatches(metadata)) {
          attributes[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
        }
        pending = attributes;
        continue;
      }
      if (line.startsWith('#') || pending == null) continue;
      final parsedUri = Uri.tryParse(line);
      final streamUri = parsedUri == null
          ? null
          : parsedUri.hasScheme
              ? parsedUri
              : baseUri?.resolveUri(parsedUri);
      if (streamUri == null ||
          !isDirectPlayableStream(streamUri.toString())) {
        pending = null;
        pendingName = '';
        continue;
      }
      final data = pending;
      result.add(M3uChannel(
        name: pendingName.isNotEmpty ? pendingName :
            (data['tvg-name'] ?? data['tvg-id'] ?? 'Canal').trim(),
        url: streamUri.toString(), tvgId: data['tvg-id'] ?? '',
        tvgName: data['tvg-name'] ?? '',
        group: data['group-title'] ?? '',
        logo: data['tvg-logo'] ?? '',
        language: data['tvg-language'] ?? data['language'] ?? '',
        country: data['tvg-country'] ?? data['country'] ?? '',
        sourceUrl: sourceUrl,
      ));
      pending = null;
      pendingName = '';
    }
    return result;
  }

  static String _m3uAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .trim();

  static String _m3uSingleLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  /// Combina los canales directos sin duplicados y conserva referencias EPG.
  static String buildMergedM3u(
    AutoLiveCatalog catalog, {
    List<String> epgUrls = const <String>[],
  }) {
    final guides = <String>{
      for (final url in epgUrls)
        if (isSafeHttpUrl(url)) url.trim(),
    }.toList(growable: false);
    final guideHeader = guides.isEmpty
        ? ''
        : ' url-tvg="${_m3uAttribute(guides.join(','))}"'
          ' x-tvg-url="${_m3uAttribute(guides.join(','))}"';
    final output = StringBuffer('#EXTM3U$guideHeader\n');
    final seen = <String>{};
    for (final channel in catalog.channels) {
      if (!isDirectPlayableStream(channel.url) || !seen.add(channel.url)) continue;
      final attributes = <String, String>{
        if (channel.tvgId.trim().isNotEmpty) 'tvg-id': channel.tvgId,
        if (channel.tvgName.trim().isNotEmpty) 'tvg-name': channel.tvgName,
        if (channel.logo.trim().isNotEmpty) 'tvg-logo': channel.logo,
        'group-title': channel.group.trim().isNotEmpty ? channel.group : 'Deportes',
        if (channel.language.trim().isNotEmpty) 'tvg-language': channel.language,
        if (channel.country.trim().isNotEmpty) 'tvg-country': channel.country,
      };
      final metadata = attributes.entries
          .map((entry) => '${entry.key}="${_m3uAttribute(entry.value)}"')
          .join(' ');
      final name = _m3uSingleLine(channel.name);
      output
        ..write('#EXTINF:-1')
        ..write(metadata.isEmpty ? '' : ' $metadata')
        ..write(',')
        ..write(name.isEmpty ? 'Canal' : name)
        ..write('\n')
        ..write(channel.url.trim())
        ..write('\n');
    }
    return output.toString();
  }

  static List<XmltvProgramme> parseXmltv(String body) {
    final document = XmlDocument.parse(body);
    final channelNames = <String, String>{};
    for (final channel in document.findAllElements('channel')) {
      final id = (channel.getAttribute('id') ?? '').trim();
      final displayNames = channel.findElements('display-name');
      final display = displayNames.isEmpty ? '' : displayNames.first.innerText.trim();
      if (id.isNotEmpty && display.isNotEmpty) channelNames[id] = display;
    }
    final result = <XmltvProgramme>[];
    for (final element in document.findAllElements('programme')) {
      final channel = (element.getAttribute('channel') ?? '').trim();
      final start = parseXmltvDate(element.getAttribute('start'));
      final stop = parseXmltvDate(element.getAttribute('stop'));
      final nodes = element.findElements('title');
      final title = nodes.isEmpty ? '' : nodes.first.innerText.trim();
      if (channel.isEmpty || title.isEmpty || start == null ||
          stop == null || !stop.isAfter(start)) continue;
      result.add(XmltvProgramme(
        channelId: channel,
        channelName: channelNames[channel] ?? '',
        title: title,
        startsAt: start,
        endsAt: stop,
      ));
    }
    return result;
  }

  static DateTime? parseXmltvDate(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{14})\s*([+-]\d{4})?$').firstMatch(value.trim());
    if (match == null) return DateTime.tryParse(value.trim())?.toLocal();
    final digits = match.group(1)!;
    final utc = DateTime.utc(
      int.parse(digits.substring(0, 4)), int.parse(digits.substring(4, 6)),
      int.parse(digits.substring(6, 8)), int.parse(digits.substring(8, 10)),
      int.parse(digits.substring(10, 12)), int.parse(digits.substring(12, 14)),
    );
    final offset = match.group(2);
    if (offset == null) return utc.toLocal();
    final sign = offset.startsWith('-') ? -1 : 1;
    final hours = int.parse(offset.substring(1, 3));
    final minutes = int.parse(offset.substring(3, 5));
    return utc.subtract(Duration(minutes: sign * (hours * 60 + minutes))).toLocal();
  }

  Future<List<ScheduledLiveEvent>> schedule({
    required List<SportsAgendaEvent> events,
    required DateTime now, required AutoLiveSettings settings,
    bool forceRefresh = false,
  }) async {
    if (!settings.isConfigured) return <ScheduledLiveEvent>[];
    final catalog = await loadCatalog(
      playlistUrl: settings.playlistUrl, epgUrl: settings.epgUrl,
      playlistText: settings.playlistText,
      playlistTexts: settings.playlistTexts,
      forceRefresh: forceRefresh,
    );
    final byId = <String, List<M3uChannel>>{};
    final byName = <String, List<M3uChannel>>{};
    for (final channel in catalog.channels) {
      if (channel.tvgId.isNotEmpty) {
        byId.putIfAbsent(channel.tvgId, () => <M3uChannel>[]).add(channel);
      }
      // Los XMLTV no siempre usan el mismo tvg-id. Se crean alias por nombre
      // de canal y por ID normalizado para mejorar el cruce entre proveedores.
      for (final rawName in <String>[channel.name, channel.tvgName, channel.tvgId]) {
        final name = normalizeText(rawName);
        if (name.isEmpty) continue;
        byName.putIfAbsent(name, () => <M3uChannel>[]).add(channel);
        final compactName = name.replaceAll(' ', '');
        if (compactName.isNotEmpty) {
          byName.putIfAbsent(compactName, () => <M3uChannel>[]).add(channel);
        }
      }
    }

    final output = <ScheduledLiveEvent>[];
    for (final event in events) {
      final prepareAt = event.startsAt.subtract(const Duration(minutes: 10));
      if (now.isBefore(prepareAt)) continue;
      final eventLimit = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      if (!now.isBefore(eventLimit)) continue;
      final programmes = catalog.programmes.where((programme) =>
        programme.startsAt.isBefore(eventLimit) &&
        programme.endsAt.isAfter(prepareAt) &&
        programmeMatchesEvent(programme.title, event)).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      final candidates = <ScheduledLiveSource>[];
      final used = <String>{};
      for (final programme in programmes) {
        final mapped = <M3uChannel>[
          ...(byId[programme.channelId] ?? <M3uChannel>[]),
          ...(programme.channelName.isEmpty
              ? <M3uChannel>[]
              : byName[normalizeText(programme.channelName)] ?? <M3uChannel>[]),
          ...(programme.channelName.isEmpty
              ? <M3uChannel>[]
              : byName[normalizeText(programme.channelName).replaceAll(' ', '')] ?? <M3uChannel>[]),
          ...(byName[normalizeText(programme.channelId)] ?? <M3uChannel>[]),
          ...(byName[normalizeText(programme.channelId).replaceAll(' ', '')] ?? <M3uChannel>[]),
        ];
        for (final channel in mapped) {
          if (!isDirectPlayableStream(channel.url) || !used.add(channel.url)) continue;
          candidates.add(ScheduledLiveSource(
            channelName: channel.name,
            url: channel.url,
            programmeTitle: programme.title,
            programmeEndsAt: programme.endsAt,
            qualityScore: _qualityScore(channel),
            languagePriority: channel.languagePriority,
          ));
        }
      }
      if (candidates.isEmpty) continue;
      // Una sola señal por evento: primero la resolución anunciada, después
      // indicadores HD/FHD/UHD y finalmente un orden estable del proveedor.
      candidates.sort((a, b) {
        final language = b.languagePriority.compareTo(a.languagePriority);
        return language != 0
            ? language
            : b.qualityScore.compareTo(a.qualityScore);
      });
      final spanishCandidates = candidates
          .where((candidate) => candidate.languagePriority > 0)
          .take(12)
          .toList(growable: false);
      final otherLanguageCandidates = candidates
          .where((candidate) => candidate.languagePriority == 0)
          .take(12)
          .toList(growable: false);

      // Primero se intentan señales en español. Solo si ninguna responde se
      // consulta el grupo internacional, sin mezclar idiomas en la prioridad.
      var checkedCandidates = await Future.wait<ScheduledLiveSource>(
        (spanishCandidates.isNotEmpty
                ? spanishCandidates
                : otherLanguageCandidates)
            .map(_probeCandidate),
      );
      var verifiedCandidates = checkedCandidates
          .where((candidate) => candidate.available)
          .toList(growable: true);
      if (verifiedCandidates.isEmpty && spanishCandidates.isNotEmpty) {
        checkedCandidates = await Future.wait<ScheduledLiveSource>(
          otherLanguageCandidates.map(_probeCandidate),
        );
        verifiedCandidates = checkedCandidates
            .where((candidate) => candidate.available)
            .toList(growable: true);
      }
      // Solo se programa una fuente cuya lista de reproducción respondió
      // correctamente a la comprobación. No se asignan señales no verificadas.
      if (verifiedCandidates.isEmpty) continue;
      // Se conserva la señal principal y hasta tres alternativas que también
      // superaron la comprobación de disponibilidad del manifiesto o medio.
      verifiedCandidates.sort((a, b) {
        final language = b.languagePriority.compareTo(a.languagePriority);
        return language != 0
            ? language
            : b.qualityScore.compareTo(a.qualityScore);
      });
      final sources = verifiedCandidates.take(4).toList(growable: false);
      final programmeEnd = sources.map((s) => s.programmeEndsAt).reduce(
        (a, b) => a.isAfter(b) ? a : b,
      );
      final removeAt = event.endsAt ?? programmeEnd;
      if (now.isBefore(removeAt)) {
        output.add(ScheduledLiveEvent(event: event, sources: sources, removeAt: removeAt));
      }
    }
    output.sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    return output;
  }

  static const Map<String, List<String>> _teamAliases = <String, List<String>>{
    'manchester united': <String>['man utd', 'man united', 'manchester utd'],
    'manchester city': <String>['man city'],
    'paris saint germain': <String>['psg', 'paris sg'],
    'atletico madrid': <String>['atleti', 'atletico de madrid'],
    'fc barcelona': <String>['barcelona', 'barca'],
    'barcelona': <String>['barca'],
    'internazionale': <String>['inter milan', 'inter'],
    'inter milan': <String>['internazionale', 'inter'],
    'bayern munich': <String>['bayern'],
    'borussia dortmund': <String>['dortmund', 'bvb'],
    'tottenham hotspur': <String>['tottenham', 'spurs'],
    'new york knicks': <String>['ny knicks'],
    'golden state warriors': <String>['gs warriors'],
    'los angeles lakers': <String>['la lakers'],
  };

  static bool _teamMatchesProgramme(String team, String programme) {
    final normalizedTeam = normalizeText(team);
    if (normalizedTeam.isEmpty) return false;
    if (programme.contains(normalizedTeam)) return true;

    final aliases = _teamAliases.entries
        .where((entry) =>
            normalizedTeam == entry.key ||
            entry.value.any((alias) => normalizeText(alias) == normalizedTeam))
        .expand((entry) => <String>[entry.key, ...entry.value])
        .map(normalizeText);
    if (aliases.any((alias) => alias.isNotEmpty && programme.contains(alias))) {
      return true;
    }

    const ignored = <String>{
      'fc', 'cf', 'afc', 'club', 'de', 'the', 'united', 'city',
      'team', 'basket', 'basketball', 'futbol', 'football',
    };
    final teamTokens = normalizedTeam
        .split(' ')
        .where((token) => token.length >= 3 && !ignored.contains(token))
        .toSet();
    if (teamTokens.isEmpty) return false;
    final programmeTokens = programme.split(' ').toSet();
    final matched = teamTokens.where((token) => programmeTokens.contains(token)).length;
    final required = teamTokens.length == 1
        ? 1
        : (teamTokens.length * 0.67).ceil();
    return matched >= required;
  }

  static bool programmeMatchesEvent(String programmeTitle, SportsAgendaEvent event) {
    final programme = normalizeText(programmeTitle);
    if (programme.isEmpty) return false;
    final home = normalizeText(event.homeTeam);
    final away = normalizeText(event.awayTeam);
    final sport = normalizeText(event.sport);
    final competition = normalizeText(event.competition);

    // UFC suele anunciar el evento y no necesariamente ambos luchadores.
    if (sport == 'mma' && competition.isNotEmpty &&
        programme.contains(competition)) {
      return true;
    }

    if (home.isNotEmpty && away.isNotEmpty) {
      return _teamMatchesProgramme(home, programme) &&
          _teamMatchesProgramme(away, programme);
    }

    // Ciclismo y motor se publican como carreras/etapas, no como partidos.
    const ignored = <String>{
      'contra', 'versus', 'partido', 'futbol', 'football', 'basket',
      'liga', 'copa', 'final', 'directo', 'vivo', 'match', 'evento',
      'hoy', 'club', 'the', 'de', 'del', 'la', 'el', 'and',
      'cycling', 'motorsport', 'race', 'stage', 'etapa', 'grand',
      'prix', 'gp', 'formula', 'moto', 'tour', 'women', 'men',
      'championship', 'series',
    };
    final tokens = normalizeText(event.title + ' ' + event.competition)
        .split(' ')
        .where((token) => token.length >= 4 &&
            !ignored.contains(token) &&
            int.tryParse(token) == null)
        .toSet();
    if (tokens.isEmpty) return false;
    final matched = tokens.where((token) => programme.contains(token)).length;
    final required = tokens.length == 1 ? 1 : (tokens.length * 0.5).ceil();
    return matched >= required;
  }

  Future<bool> _probeMediaBytes(Uri uri) async {
    try {
      final request = http.Request('GET', uri)
        ..headers['Range'] = 'bytes=0-2047'
        ..headers['Accept'] = '*/*';
      final response = await _client.send(request)
          .timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        return false;
      }
      var received = 0;
      await for (final chunk in response.stream.timeout(const Duration(seconds: 7))) {
        received += chunk.length;
        if (received >= 2048) break;
      }
      return received > 0;
    } catch (_) {
      return false;
    }
  }

  Future<({bool available, int quality})> _probeHls(
    Uri uri, {
    int depth = 0,
  }) async {
    if (depth > 2) return (available: false, quality: 0);
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/vnd.apple.mpegurl,*/*',
          'Range': 'bytes=0-1048575',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 && response.statusCode != 206) {
        return (available: false, quality: 0);
      }
      final body = utf8.decode(
        response.bodyBytes.take(1024 * 1024).toList(),
        allowMalformed: true,
      );
      if (!body.trimLeft().startsWith('#EXTM3U')) {
        return (available: false, quality: 0);
      }

      final resolutions = RegExp(r'RESOLUTION=\d+x(\d+)')
          .allMatches(body)
          .map((match) => int.tryParse(match.group(1) ?? '') ?? 0);
      final maxHeight = resolutions.isEmpty ? 0 : resolutions.reduce(
        (a, b) => a > b ? a : b,
      );
      final bandwidths = RegExp(r'BANDWIDTH=(\d+)')
          .allMatches(body)
          .map((match) => int.tryParse(match.group(1) ?? '') ?? 0);
      final maxBandwidth = bandwidths.isEmpty ? 0 : bandwidths.reduce(
        (a, b) => a > b ? a : b,
      );
      final quality = maxHeight >= 2160 || maxBandwidth >= 12000000 ? 500 :
          maxHeight >= 1080 || maxBandwidth >= 6000000 ? 400 :
          maxHeight >= 720 || maxBandwidth >= 3000000 ? 300 :
          maxHeight >= 480 || maxBandwidth >= 1200000 ? 200 : 50;

      final lines = body.replaceAll('\r', '').split('\n');
      final variants = <({int bandwidth, String url})>[];
      for (var index = 0; index < lines.length - 1; index++) {
        final line = lines[index].trim();
        if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
        var next = index + 1;
        while (next < lines.length && lines[next].trim().isEmpty) {
          next++;
        }
        if (next >= lines.length || lines[next].trim().startsWith('#')) continue;
        final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        variants.add((
          bandwidth: int.tryParse(match?.group(1) ?? '') ?? 0,
          url: lines[next].trim(),
        ));
      }
      if (variants.isNotEmpty) {
        variants.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
        for (final variant in variants.take(3)) {
          final nested = await _probeHls(uri.resolve(variant.url), depth: depth + 1);
          if (nested.available) {
            return (available: true, quality: quality > nested.quality ? quality : nested.quality);
          }
        }
        return (available: false, quality: quality);
      }

      String? segment;
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        segment = line;
        break;
      }
      segment ??= RegExp(r'URI="([^"]+)"')
          .firstMatch(body)
          ?.group(1);
      if (segment == null) return (available: false, quality: quality);

      final segmentAvailable = await _probeMediaBytes(uri.resolve(segment));
      return (available: segmentAvailable, quality: quality);
    } catch (_) {
      return (available: false, quality: 0);
    }
  }


  Future<bool> _probeDashManifest(Uri uri) async {
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/dash+xml,application/xml,text/xml,*/*',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final bytes = response.bodyBytes.take(1024 * 1024).toList();
      final body = utf8.decode(bytes, allowMalformed: true);
      final document = XmlDocument.parse(body);
      if (document.rootElement.name.local.toLowerCase() != 'mpd') {
        return false;
      }
      return document.findAllElements('Period').any(
        (period) => period.findElements('AdaptationSet').isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeSmoothStreamingManifest(Uri uri) async {
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/vnd.ms-sstr+xml,application/xml,*/*',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final body = utf8.decode(
        response.bodyBytes.take(1024 * 1024).toList(),
        allowMalformed: true,
      );
      final document = XmlDocument.parse(body);
      return document.rootElement.name.local.toLowerCase() ==
          'smoothstreamingmedia';
    } catch (_) {
      return false;
    }
  }

  Future<ScheduledLiveSource> _probeCandidate(
    ScheduledLiveSource source,
  ) async {
    final cached = _probeCache[source.url];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.checkedAt) < const Duration(seconds: 75)) {
      return ScheduledLiveSource(
        channelName: source.channelName,
        url: source.url,
        programmeTitle: source.programmeTitle,
        programmeEndsAt: source.programmeEndsAt,
        qualityScore: source.qualityScore + cached.quality,
        languagePriority: source.languagePriority,
        available: cached.available,
      );
    }

    var available = false;
    var extraQuality = 0;
    try {
      final uri = Uri.parse(source.url);
      switch (liveMediaFormatForUrl(source.url)) {
        case LiveMediaFormat.hls:
          final probe = await _probeHls(uri);
          available = probe.available;
          extraQuality = probe.quality;
        case LiveMediaFormat.dash:
          available = await _probeDashManifest(uri);
        case LiveMediaFormat.smoothStreaming:
          available = await _probeSmoothStreamingManifest(uri);
        case LiveMediaFormat.progressive:
          // Incluye MP4 y MPEG-TS directo. En HLS, los segmentos .ts
          // se entregan al motor a través del manifiesto .m3u8.
          available = await _probeMediaBytes(uri);
        case null:
          available = false;
      }
    } catch (_) {
      available = false;
    }
    _probeCache[source.url] = (
      available: available,
      quality: extraQuality,
      checkedAt: now,
    );
    return ScheduledLiveSource(
      channelName: source.channelName,
      url: source.url,
      programmeTitle: source.programmeTitle,
      programmeEndsAt: source.programmeEndsAt,
      qualityScore: source.qualityScore + extraQuality,
      languagePriority: source.languagePriority,
      available: available,
    );
  }

  static int _qualityScore(M3uChannel channel) {
    final metadata = normalizeText(
      '${channel.name} ${channel.tvgName} ${channel.group} ${channel.logo}',
    );
    final url = channel.url.toLowerCase();
    if (RegExp(r'4k|uhd|2160p?').hasMatch(metadata) || url.contains('2160')) return 500;
    if (RegExp(r'1080p?|full hd|fhd').hasMatch(metadata) || url.contains('1080')) return 400;
    if (RegExp(r'720p?|hd').hasMatch(metadata) || url.contains('720')) return 300;
    if (RegExp(r'576p?|480p?|sd').hasMatch(metadata) || url.contains('480')) return 200;
    return 100;
  }

  static String normalizeText(String value) {
    var text = value.toLowerCase();
    const replacements = <String, String>{
      'á':'a','é':'e','í':'i','ó':'o','ú':'u','ü':'u','ñ':'n',
      'à':'a','è':'e','ì':'i','ò':'o','ù':'u',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
