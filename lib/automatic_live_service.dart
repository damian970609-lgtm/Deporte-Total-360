import 'dart:convert';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

const String _playlistUrlKey = 'dt360_auto_live_playlist_url_v1';
const String _epgUrlKey = 'dt360_auto_live_epg_url_v1';
const String _authorizedKey = 'dt360_auto_live_authorized_v1';

/// Catálogos globales y una lista adicional de emisoras deportivas públicas.
/// La presencia en un índice no sustituye la comprobación de derechos del emisor.
const String legacyDefaultAutoLivePlaylistUrls =
    'https://dearbulut.github.io/iptv/playlists/category/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/online.m3u\n'
    'https://iptv-org.github.io/iptv/categories/sports.m3u';
const String legacyDefaultAutoLiveEpgUrl =
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz';

const String defaultAutoLivePlaylistUrls =
    'https://dearbulut.github.io/iptv/playlists/category/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/online.m3u\n'
    'https://iptv-org.github.io/iptv/categories/sports.m3u\n'
    'https://raw.githubusercontent.com/freecasthub/public-iptv/main/sports.m3u\n'
    'https://dearbulut.github.io/iptv/playlists/best.m3u';

const String defaultAutoLiveEpgUrl =
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz\n'
    'https://iptv-epg.org/files/epg-cw.xml\n'
    'https://iptv-epg.org/files/epg-jm.xml\n'
    'https://iptv-epg.org/files/epg-co.xml\n'
    'https://iptv-epg.org/files/epg-ve.xml\n'
    'https://iptv-epg.org/files/epg-pa.xml\n'
    'https://iptv-epg.org/files/epg-br.xml\n'
    'https://iptv-epg.org/files/epg-ar.xml\n'
    'https://iptv-epg.org/files/epg-mx.xml\n'
    'https://iptv-epg.org/files/epg-cl.xml\n'
    'https://iptv-epg.org/files/epg-es.xml';

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

bool isDirectPlayableStream(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !isSafeHttpUrl(value)) return false;
  final path = uri.path.toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.mp4') || path.endsWith('.ts');
}

class AutoLiveSettings {
  const AutoLiveSettings({
    required this.playlistUrl,
    required this.epgUrl,
    required this.authorizationConfirmed,
  });
  final String playlistUrl;
  final String epgUrl;
  final bool authorizationConfirmed;

  List<String> get playlistUrls => _splitPlaylistUrls(playlistUrl);
  List<String> get epgUrls => _splitPlaylistUrls(epgUrl);

  bool get isConfigured => authorizationConfirmed &&
      playlistUrls.isNotEmpty &&
      playlistUrls.every(isSafeHttpUrl) &&
      epgUrls.isNotEmpty &&
      epgUrls.every(isSafeHttpUrl);

  static Future<AutoLiveSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var playlist = prefs.getString(_playlistUrlKey) ?? defaultAutoLivePlaylistUrls;
    var epg = prefs.getString(_epgUrlKey) ?? defaultAutoLiveEpgUrl;

    // Migra la configuración predeterminada anterior sin sobrescribir listas
    // o guías personalizadas que el usuario haya guardado.
    if (playlist.trim() == legacyDefaultAutoLivePlaylistUrls.trim()) {
      playlist = defaultAutoLivePlaylistUrls;
      await prefs.setString(_playlistUrlKey, playlist);
    }
    if (epg.trim() == legacyDefaultAutoLiveEpgUrl.trim()) {
      epg = defaultAutoLiveEpgUrl;
      await prefs.setString(_epgUrlKey, epg);
    }

    return AutoLiveSettings(
      playlistUrl: playlist,
      epgUrl: epg,
      authorizationConfirmed: prefs.getBool(_authorizedKey) ?? false,
    );
  }

  static Future<void> save({
    required String playlistUrl,
    required String epgUrl,
    required bool authorizationConfirmed,
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
    if (!authorizationConfirmed) {
      throw const FormatException('Confirma que tienes derecho a reproducir las señales de la lista.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistUrlKey, playlist);
    await prefs.setString(_epgUrlKey, epg);
    await prefs.setBool(_authorizedKey, true);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // Valores vacíos evitan que los valores predeterminados vuelvan a aparecer
    // inmediatamente después de que el usuario pulse Borrar.
    await prefs.setString(_playlistUrlKey, '');
    await prefs.setString(_epgUrlKey, '');
    await prefs.setBool(_authorizedKey, false);
  }
}

class FutbolLibreEvent {
  const FutbolLibreEvent({
    required this.id,
    required this.title,
    required this.sport,
    required this.startsAt,
    required this.detailUrl,
    this.competition = '',
    this.homeTeam = '',
    this.awayTeam = '',
    this.endsAt,
  });
  final String id;
  final String title;
  final String sport;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String detailUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id, 'title': title, 'sport': sport, 'competition': competition,
    'homeTeam': homeTeam, 'awayTeam': awayTeam,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(), 'detailUrl': detailUrl,
  };

  static FutbolLibreEvent? fromJson(dynamic value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final id = (row['id'] ?? '').toString().trim();
    final title = (row['title'] ?? '').toString().trim();
    final startsAt = DateTime.tryParse((row['startsAt'] ?? '').toString());
    final detailUrl = (row['detailUrl'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty || startsAt == null ||
        !isSafeHttpUrl(detailUrl)) return null;
    final end = DateTime.tryParse((row['endsAt'] ?? '').toString());
    return FutbolLibreEvent(
      id: id, title: title, sport: (row['sport'] ?? 'Fútbol').toString(),
      competition: (row['competition'] ?? '').toString(),
      homeTeam: (row['homeTeam'] ?? '').toString(),
      awayTeam: (row['awayTeam'] ?? '').toString(),
      startsAt: startsAt.toLocal(), endsAt: end?.toLocal(),
      detailUrl: detailUrl,
    );
  }
}

class FutbolLibreAgendaStore {
  static const String _key = 'dt360_futbol_libre_events_v1';

  static Future<void> save(List<FutbolLibreEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await load();
    final unique = <String, FutbolLibreEvent>{
      for (final event in previous) event.id: event,
    };
    for (final event in events) {
      unique[event.id] = event;
    }
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

  static Future<List<FutbolLibreEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <FutbolLibreEvent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <FutbolLibreEvent>[];
      return decoded.map(FutbolLibreEvent.fromJson)
          .whereType<FutbolLibreEvent>().toList(growable: false);
    } catch (_) { return <FutbolLibreEvent>[]; }
  }
}

class M3uChannel {
  const M3uChannel({
    required this.name, required this.url, this.tvgId = '',
    this.tvgName = '', this.group = '', this.logo = '',
  });
  final String name;
  final String url;
  final String tvgId;
  final String tvgName;
  final String group;
  final String logo;
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
    this.available = false,
  });
  final String channelName;
  final String url;
  final String programmeTitle;
  final DateTime programmeEndsAt;
  final int qualityScore;
  final bool available;
}

class ScheduledLiveEvent {
  const ScheduledLiveEvent({
    required this.event, required this.sources, required this.removeAt,
  });
  final FutbolLibreEvent event;
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
  AutoLiveCatalog? _cachedCatalog;
  DateTime? _cachedAt;
  String? _cachedPlaylist;
  String? _cachedEpg;
  final Map<String, ({bool available, int quality, DateTime checkedAt})> _probeCache =
      <String, ({bool available, int quality, DateTime checkedAt})>{};

  Future<AutoLiveCatalog> loadCatalog({
    required String playlistUrl, required String epgUrl,
    bool forceRefresh = false,
  }) async {
    final playlistUrls = _splitPlaylistUrls(playlistUrl);
    final epgUrls = _splitPlaylistUrls(epgUrl);
    if (playlistUrls.isEmpty ||
        !playlistUrls.every(isSafeHttpUrl) ||
        epgUrls.isEmpty ||
        !epgUrls.every(isSafeHttpUrl)) {
      throw const FormatException('Configura listas M3U y guías XMLTV/EPG con direcciones HTTP o HTTPS válidas.');
    }
    final playlistCacheKey = playlistUrls.join('\n');
    final epgCacheKey = epgUrls.join('\n');
    final now = DateTime.now();
    final cached = _cachedCatalog;
    if (!forceRefresh && cached != null &&
        _cachedPlaylist == playlistCacheKey && _cachedEpg == epgCacheKey &&
        _cachedAt != null && now.difference(_cachedAt!) < const Duration(minutes: 5)) {
      return cached;
    }

    // Cada M3U es independiente: una caída no bloquea las listas de respaldo.
    final playlistBodies = await Future.wait<String?>(
      playlistUrls.map((url) async {
        try {
          return await _downloadText(url, maxBytes: 12 * 1024 * 1024);
        } catch (_) {
          return null;
        }
      }),
    );
    final channelsByUrl = <String, M3uChannel>{};
    for (final body in playlistBodies.whereType<String>()) {
      for (final channel in parseM3u(body)) {
        channelsByUrl.putIfAbsent(channel.url, () => channel);
      }
    }
    final channels = channelsByUrl.values.toList(growable: false);
    if (channels.isEmpty) {
      throw const FormatException('Ninguna lista M3U respondió con canales HLS/MP4/TS compatibles.');
    }

    // Se fusionan varias guías. Si una EPG no responde o publica XML inválido,
    // las demás siguen aportando programas. Las guías regionales tienen un
    // límite menor para cuidar la memoria del teléfono.
    final programmesByKey = <String, XmltvProgramme>{};
    for (var index = 0; index < epgUrls.length; index++) {
      try {
        final epgBody = await _downloadText(
          epgUrls[index],
          maxBytes: index == 0 ? 128 * 1024 * 1024 : 24 * 1024 * 1024,
          timeout: const Duration(seconds: 12),
        );
        for (final programme in parseXmltv(epgBody)) {
          final key = <String>[
            programme.channelId.toLowerCase(),
            programme.title.toLowerCase().trim(),
            programme.startsAt.toUtc().toIso8601String(),
            programme.endsAt.toUtc().toIso8601String(),
          ].join('|');
          programmesByKey.putIfAbsent(key, () => programme);
        }
      } catch (_) {
        // Fallback: continuar con la siguiente guía regional/global.
      }
    }
    final programmes = programmesByKey.values.toList(growable: false);
    if (programmes.isEmpty) {
      throw const FormatException('Ninguna guía EPG/XMLTV respondió con programas legibles.');
    }

    final catalog = AutoLiveCatalog(channels: channels, programmes: programmes);
    _cachedCatalog = catalog;
    _cachedAt = now;
    _cachedPlaylist = playlistCacheKey;
    _cachedEpg = epgCacheKey;
    return catalog;
  }

  Future<String> _downloadText(
    String value, {
    required int maxBytes,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final response = await _client.get(Uri.parse(value.trim()),
      headers: const <String, String>{'Accept': '*/*'})
      .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('La fuente respondió HTTP ' + response.statusCode.toString() + '.');
    }
    List<int> bytes = response.bodyBytes;
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        bytes = gzip.decode(bytes);
      } catch (_) {
        throw const FormatException('No se pudo descomprimir la fuente GZIP.');
      }
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('El archivo supera el tamaño máximo permitido.');
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    if (body.trim().isEmpty) throw const FormatException('La fuente está vacía.');
    return body;
  }

  static List<M3uChannel> parseM3u(String body) {
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
      if (!isDirectPlayableStream(line)) {
        pending = null;
        pendingName = '';
        continue;
      }
      final data = pending;
      result.add(M3uChannel(
        name: pendingName.isNotEmpty ? pendingName :
            (data['tvg-name'] ?? data['tvg-id'] ?? 'Canal').trim(),
        url: line, tvgId: data['tvg-id'] ?? '',
        tvgName: data['tvg-name'] ?? '',
        group: data['group-title'] ?? '', logo: data['tvg-logo'] ?? '',
      ));
      pending = null;
      pendingName = '';
    }
    return result;
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
    required List<FutbolLibreEvent> events,
    required DateTime now, required AutoLiveSettings settings,
    bool forceRefresh = false,
  }) async {
    if (!settings.isConfigured) return <ScheduledLiveEvent>[];
    final catalog = await loadCatalog(
      playlistUrl: settings.playlistUrl, epgUrl: settings.epgUrl,
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
          ));
        }
      }
      if (candidates.isEmpty) continue;
      // Una sola señal por evento: primero la resolución anunciada, después
      // indicadores HD/FHD/UHD y finalmente un orden estable del proveedor.
      candidates.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
      final checkedCandidates = await Future.wait<ScheduledLiveSource>(
        candidates.take(12).map(_probeCandidate),
      );
      final verifiedCandidates = checkedCandidates
          .where((candidate) => candidate.available)
          .toList(growable: true);
      // Solo se programa una fuente cuya lista de reproducción respondió
      // correctamente a la comprobación. No se asignan señales no verificadas.
      if (verifiedCandidates.isEmpty) continue;
      // Entre las señales disponibles, se conserva una sola: la de mayor
      // calidad anunciada y confirmada por la lista HLS.
      verifiedCandidates.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
      final sources = <ScheduledLiveSource>[verifiedCandidates.first];
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

  static bool programmeMatchesEvent(String programmeTitle, FutbolLibreEvent event) {
    final programme = normalizeText(programmeTitle);
    if (programme.isEmpty) return false;
    final home = normalizeText(event.homeTeam);
    final away = normalizeText(event.awayTeam);
    if (home.isNotEmpty && away.isNotEmpty) {
      return programme.contains(home) && programme.contains(away);
    }
    const ignored = <String>{
      'contra','versus','partido','futbol','football','basket','liga',
      'copa','final','directo','vivo','match','evento','hoy',
    };
    final tokens = normalizeText(event.title).split(' ')
        .where((t) => t.length >= 4 && !ignored.contains(t)).toSet();
    if (tokens.length < 2) return false;
    return tokens.where((token) => programme.contains(token)).length >= 2;
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
        available: cached.available,
      );
    }

    var available = false;
    var extraQuality = 0;
    try {
      final uri = Uri.parse(source.url);
      if (uri.path.toLowerCase().endsWith('.m3u8')) {
        final response = await _client.get(uri,
          headers: const <String, String>{'Accept': 'application/vnd.apple.mpegurl,*/*'})
          .timeout(const Duration(seconds: 8));
        final body = utf8.decode(
          response.bodyBytes.take(1024 * 1024).toList(),
          allowMalformed: true,
        );
        available = response.statusCode == 200 &&
            body.trimLeft().startsWith('#EXTM3U');
        if (available) {
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
          extraQuality = maxHeight >= 2160 || maxBandwidth >= 12000000 ? 500 :
              maxHeight >= 1080 || maxBandwidth >= 6000000 ? 400 :
              maxHeight >= 720 || maxBandwidth >= 3000000 ? 300 :
              maxHeight >= 480 || maxBandwidth >= 1200000 ? 200 : 50;
        }
      } else {
        final request = http.Request('HEAD', uri);
        final response = await _client.send(request)
            .timeout(const Duration(seconds: 8));
        available = response.statusCode >= 200 && response.statusCode < 400;
        await response.stream.drain<void>();
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
