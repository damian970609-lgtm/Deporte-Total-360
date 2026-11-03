import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

const String _playlistUrlKey = 'dt360_auto_live_playlist_url_v1';
const String _epgUrlKey = 'dt360_auto_live_epg_url_v1';
const String _authorizedKey = 'dt360_auto_live_authorized_v1';

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
  return path.endsWith('.m3u8') || path.endsWith('.mp4');
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

  bool get isConfigured => authorizationConfirmed &&
      isSafeHttpUrl(playlistUrl) && isSafeHttpUrl(epgUrl);

  static Future<AutoLiveSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AutoLiveSettings(
      playlistUrl: prefs.getString(_playlistUrlKey) ?? '',
      epgUrl: prefs.getString(_epgUrlKey) ?? '',
      authorizationConfirmed: prefs.getBool(_authorizedKey) ?? false,
    );
  }

  static Future<void> save({
    required String playlistUrl,
    required String epgUrl,
    required bool authorizationConfirmed,
  }) async {
    final playlist = playlistUrl.trim();
    final epg = epgUrl.trim();
    if (!isSafeHttpUrl(playlist) || !isSafeHttpUrl(epg)) {
      throw const FormatException('Las direcciones M3U y EPG deben ser HTTP o HTTPS válidas.');
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
    await prefs.remove(_playlistUrlKey);
    await prefs.remove(_epgUrlKey);
    await prefs.remove(_authorizedKey);
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
    final unique = <String, FutbolLibreEvent>{};
    for (final event in events) { unique[event.id] = event; }
    await prefs.setString(_key,
        jsonEncode(unique.values.map((event) => event.toJson()).toList()));
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
  });
  final String channelId;
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
    if (!isSafeHttpUrl(playlistUrl) || !isSafeHttpUrl(epgUrl)) {
      throw const FormatException('Configura una URL válida para M3U y otra para XMLTV/EPG.');
    }
    final now = DateTime.now();
    final cached = _cachedCatalog;
    if (!forceRefresh && cached != null &&
        _cachedPlaylist == playlistUrl && _cachedEpg == epgUrl &&
        _cachedAt != null && now.difference(_cachedAt!) < const Duration(minutes: 5)) {
      return cached;
    }
    final bodies = await Future.wait<String>(<Future<String>>[
      _downloadText(playlistUrl, maxBytes: 12 * 1024 * 1024),
      _downloadText(epgUrl, maxBytes: 32 * 1024 * 1024),
    ]);
    final channels = parseM3u(bodies[0]);
    final programmes = parseXmltv(bodies[1]);
    if (channels.isEmpty) {
      throw const FormatException('La lista M3U no contiene canales HLS o MP4 compatibles.');
    }
    if (programmes.isEmpty) {
      throw const FormatException('La EPG XMLTV no contiene programas legibles.');
    }
    final catalog = AutoLiveCatalog(channels: channels, programmes: programmes);
    _cachedCatalog = catalog;
    _cachedAt = now;
    _cachedPlaylist = playlistUrl;
    _cachedEpg = epgUrl;
    return catalog;
  }

  Future<String> _downloadText(String value, {required int maxBytes}) async {
    final response = await _client.get(Uri.parse(value.trim()),
      headers: const <String, String>{'Accept': '*/*'})
      .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('La fuente respondió HTTP ' + response.statusCode.toString() + '.');
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const FormatException('El archivo supera el tamaño máximo permitido.');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
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
        channelId: channel, title: title, startsAt: start, endsAt: stop,
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
      final name = normalizeText(channel.tvgName.isNotEmpty ? channel.tvgName : channel.name);
      if (name.isNotEmpty) byName.putIfAbsent(name, () => <M3uChannel>[]).add(channel);
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
          ...(byName[normalizeText(programme.channelId)] ?? <M3uChannel>[]),
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
      final sources = <ScheduledLiveSource>[];
      for (final candidate in candidates.take(6)) {
        final checked = await _probeCandidate(candidate);
        if (checked.available) {
          sources.add(checked);
          break;
        }
      }
      // Algunos proveedores legítimos rechazan HEAD/GET de comprobación aunque
      // ExoPlayer pueda reproducir con sus reglas de red. En ese caso se deja
      // una sola mejor candidata, marcada como no verificada.
      if (sources.isEmpty) {
        sources.add(candidates.first);
      }
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
          extraQuality = maxHeight >= 2160 ? 500 :
              maxHeight >= 1080 ? 400 :
              maxHeight >= 720 ? 300 :
              maxHeight >= 480 ? 200 : 50;
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
