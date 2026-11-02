import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

class ChannelCatalogConfig {
  const ChannelCatalogConfig({required this.playlistUrl, required this.epgUrl});
  final String playlistUrl;
  final String epgUrl;
}

class TvCatalogChannel {
  const TvCatalogChannel({required this.name, required this.url, this.group = '', this.tvgId = ''});
  final String name;
  final String url;
  final String group;
  final String tvgId;
}

class TvGuideProgramme {
  const TvGuideProgramme({required this.channelId, required this.title, required this.startsAt, required this.endsAt});
  final String channelId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
}

class ChannelMatchQuery {
  const ChannelMatchQuery({
    required this.id,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.competition,
    required this.startsAt,
  });

  final String id;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final String competition;
  final DateTime startsAt;
}

class ChannelMatchSuggestion {
  const ChannelMatchSuggestion({required this.channelName, required this.url, required this.programmeTitle, required this.programmeStartsAt, required this.programmeEndsAt});
  final String channelName;
  final String url;
  final String programmeTitle;
  final DateTime programmeStartsAt;
  final DateTime programmeEndsAt;
}

/// Uses only an M3U playlist and XMLTV guide explicitly configured by the app owner.
class ChannelCatalogService {
  ChannelCatalogService({http.Client? client}) : _client = client ?? http.Client();
  static final ChannelCatalogService instance = ChannelCatalogService();

  static const String playlistPreferenceKey = 'authorized_tv_playlist_url';
  static const String epgPreferenceKey = 'authorized_tv_epg_url';
  static const int maxPlaylistBytes = 5 * 1024 * 1024;
  static const int maxEpgBytes = 12 * 1024 * 1024;
  static const Duration cacheDuration = Duration(minutes: 15);

  final http.Client _client;
  DateTime? _cacheExpiresAt;
  String? _cacheKey;
  List<TvCatalogChannel> _cachedChannels = const <TvCatalogChannel>[];
  List<TvGuideProgramme> _cachedProgrammes = const <TvGuideProgramme>[];

  Future<ChannelCatalogConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return ChannelCatalogConfig(
      playlistUrl: prefs.getString(playlistPreferenceKey) ?? '',
      epgUrl: prefs.getString(epgPreferenceKey) ?? '',
    );
  }

  Future<void> saveConfig({required String playlistUrl, required String epgUrl}) async {
    final playlist = _validateHttpsUrl(playlistUrl, required: true);
    final epg = _validateHttpsUrl(epgUrl, required: false);
    if (playlist == null) throw const FormatException('La lista M3U debe ser una URL HTTPS válida.');
    if (epgUrl.trim().isNotEmpty && epg == null) {
      throw const FormatException('La guía XMLTV debe ser una URL HTTPS válida.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(playlistPreferenceKey, playlist);
    await prefs.setString(epgPreferenceKey, epg ?? '');
    clearCache();
  }

  static String? _validateHttpsUrl(String value, {required bool required}) {
    final text = value.trim();
    if (text.isEmpty) return required ? null : '';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment) return null;
    return uri.toString();
  }

  void clearCache() {
    _cacheExpiresAt = null;
    _cacheKey = null;
    _cachedChannels = const <TvCatalogChannel>[];
    _cachedProgrammes = const <TvGuideProgramme>[];
  }

  Future<int> testPlaylist() async {
    final snapshot = await _loadSnapshot(await loadConfig());
    return snapshot.channels.length;
  }

  Future<Map<String, List<ChannelMatchSuggestion>>> findMatchesForEvents(
    List<ChannelMatchQuery> events,
  ) async {
    final config = await loadConfig();
    if (config.playlistUrl.isEmpty || config.epgUrl.isEmpty) {
      return const <String, List<ChannelMatchSuggestion>>{};
    }
    final snapshot = await _loadSnapshot(config);
    return <String, List<ChannelMatchSuggestion>>{
      for (final event in events)
        event.id: matchEvent(
          channels: snapshot.channels,
          programmes: snapshot.programmes,
          sport: event.sport,
          homeTeam: event.homeTeam,
          awayTeam: event.awayTeam,
          competition: event.competition,
          startsAt: event.startsAt,
        ),
    };
  }

  Future<List<ChannelMatchSuggestion>> findMatchesForEvent({
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required String competition,
    required DateTime startsAt,
  }) async {
    final config = await loadConfig();
    if (config.playlistUrl.isEmpty || config.epgUrl.isEmpty) return const <ChannelMatchSuggestion>[];
    final snapshot = await _loadSnapshot(config);
    return matchEvent(
      channels: snapshot.channels,
      programmes: snapshot.programmes,
      sport: sport,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      competition: competition,
      startsAt: startsAt,
    );
  }

  Future<_CatalogSnapshot> _loadSnapshot(ChannelCatalogConfig config) async {
    final key = '${config.playlistUrl}\n${config.epgUrl}';
    if (_cacheKey == key && _cacheExpiresAt != null && DateTime.now().isBefore(_cacheExpiresAt!)) {
      return _CatalogSnapshot(_cachedChannels, _cachedProgrammes);
    }
    if (config.playlistUrl.isEmpty || config.epgUrl.isEmpty) {
      return const _CatalogSnapshot(<TvCatalogChannel>[], <TvGuideProgramme>[]);
    }
    final playlistResponse = await _client.get(Uri.parse(config.playlistUrl)).timeout(const Duration(seconds: 20));
    if (playlistResponse.statusCode != 200) {
      throw FormatException('La lista M3U respondió HTTP ${playlistResponse.statusCode}.');
    }
    if (playlistResponse.bodyBytes.length > maxPlaylistBytes) {
      throw const FormatException('La lista M3U supera el tamaño permitido de 5 MB.');
    }
    final epgResponse = await _client.get(Uri.parse(config.epgUrl)).timeout(const Duration(seconds: 25));
    if (epgResponse.statusCode != 200) {
      throw FormatException('La guía XMLTV respondió HTTP ${epgResponse.statusCode}.');
    }
    if (epgResponse.bodyBytes.length > maxEpgBytes) {
      throw const FormatException('La guía XMLTV supera el tamaño permitido de 12 MB.');
    }
    final channels = parseM3u(utf8.decode(playlistResponse.bodyBytes, allowMalformed: true));
    final programmes = parseXmlTv(utf8.decode(epgResponse.bodyBytes, allowMalformed: true));
    _cachedChannels = channels;
    _cachedProgrammes = programmes;
    _cacheKey = key;
    _cacheExpiresAt = DateTime.now().add(cacheDuration);
    return _CatalogSnapshot(channels, programmes);
  }

  static List<TvCatalogChannel> parseM3u(String content) {
    final result = <TvCatalogChannel>[];
    String? pendingName;
    String pendingGroup = '';
    String pendingTvgId = '';
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        final metadata = comma >= 0 ? line.substring(0, comma) : line;
        final displayName = comma >= 0 ? line.substring(comma + 1).trim() : '';
        final attributes = <String, String>{};
        for (final match in RegExp(r'([\w-]+)="([^"]*)"').allMatches(metadata)) {
          attributes[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
        }
        pendingTvgId = attributes['tvg-id'] ?? '';
        pendingGroup = attributes['group-title'] ?? '';
        pendingName = (attributes['tvg-name'] ?? '').trim().isNotEmpty
            ? attributes['tvg-name']!.trim() : displayName;
        continue;
      }
      if (line.startsWith('#') || pendingName == null || pendingName!.isEmpty) continue;
      final uri = Uri.tryParse(line);
      final path = uri?.path.toLowerCase() ?? '';
      final supportedFormat = path.endsWith('.m3u8') || path.endsWith('.mpd');
      if (uri != null && uri.hasAuthority && uri.host.isNotEmpty &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.userInfo.isEmpty && supportedFormat) {
        result.add(TvCatalogChannel(name: pendingName!, url: uri.toString(), group: pendingGroup, tvgId: pendingTvgId));
      }
      pendingName = null;
      pendingGroup = '';
      pendingTvgId = '';
    }
    final seen = <String>{};
    return result.where((channel) => seen.add(channel.url)).toList(growable: false);
  }

  static List<TvGuideProgramme> parseXmlTv(String content) {
    final document = XmlDocument.parse(content);
    final result = <TvGuideProgramme>[];
    for (final element in document.findAllElements('programme')) {
      final channelId = element.getAttribute('channel')?.trim() ?? '';
      final startsAt = _parseXmlTvDate(element.getAttribute('start'));
      final endsAt = _parseXmlTvDate(element.getAttribute('stop'));
      final titles = element.findElements('title');
      final title = titles.isEmpty ? '' : titles.first.innerText.trim();
      if (channelId.isEmpty || title.isEmpty || startsAt == null || endsAt == null || !endsAt.isAfter(startsAt)) continue;
      result.add(TvGuideProgramme(channelId: channelId, title: title, startsAt: startsAt, endsAt: endsAt));
    }
    return result;
  }

  static DateTime? _parseXmlTvDate(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?').firstMatch(raw.trim());
    if (match == null) return null;
    try {
      final localAsUtc = DateTime.utc(
        int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!),
        int.parse(match.group(4)!), int.parse(match.group(5)!), int.parse(match.group(6)!),
      );
      final sign = match.group(7);
      if (sign == null) return localAsUtc;
      final offset = Duration(hours: int.parse(match.group(8)!), minutes: int.parse(match.group(9)!));
      return sign == '+' ? localAsUtc.subtract(offset) : localAsUtc.add(offset);
    } catch (_) {
      return null;
    }
  }

  static List<ChannelMatchSuggestion> matchEvent({
    required List<TvCatalogChannel> channels,
    required List<TvGuideProgramme> programmes,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required String competition,
    required DateTime startsAt,
  }) {
    final home = _normalise(homeTeam);
    final away = _normalise(awayTeam);
    if (home.isEmpty || away.isEmpty) return const <ChannelMatchSuggestion>[];
    final channelById = <String, TvCatalogChannel>{
      for (final channel in channels)
        if (channel.tvgId.trim().isNotEmpty) channel.tvgId.trim(): channel,
    };
    final from = startsAt.subtract(const Duration(hours: 1));
    final until = startsAt.add(const Duration(hours: 2));
    final suggestions = <ChannelMatchSuggestion>[];
    for (final programme in programmes) {
      if (programme.startsAt.isAfter(until) || programme.endsAt.isBefore(from)) continue;
      final title = _normalise(programme.title);
      if (!_teamAppears(title, home) || !_teamAppears(title, away)) continue;
      final channel = channelById[programme.channelId];
      if (channel == null) continue;
      suggestions.add(ChannelMatchSuggestion(
        channelName: channel.name,
        url: channel.url,
        programmeTitle: programme.title,
        programmeStartsAt: programme.startsAt,
        programmeEndsAt: programme.endsAt,
      ));
    }
    final seen = <String>{};
    suggestions.sort((a, b) => a.programmeStartsAt.compareTo(b.programmeStartsAt));
    return suggestions.where((suggestion) => seen.add(suggestion.url)).take(6).toList(growable: false);
  }

  static bool _teamAppears(String title, String team) {
    if (team.isEmpty || title.isEmpty) return false;
    if (title.contains(team)) return true;
    final tokens = team.split(' ').where((token) => token.length >= 4).toList();
    return tokens.isNotEmpty && tokens.any(title.contains);
  }

  static String _normalise(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ñ': 'n',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

class _CatalogSnapshot {
  const _CatalogSnapshot(this.channels, this.programmes);
  final List<TvCatalogChannel> channels;
  final List<TvGuideProgramme> programmes;
}
