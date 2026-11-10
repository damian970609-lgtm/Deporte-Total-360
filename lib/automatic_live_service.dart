import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'live_media_format.dart';
import 'sports_api_service.dart';

const String _playlistUrlKey = 'dt360_auto_live_playlist_url_v1';
const String _epgUrlKey = 'dt360_auto_live_epg_url_v1';
const String _authorizedKey = 'dt360_auto_live_authorized_v1';

/// Normaliza imágenes remotas de eventos. Solo acepta URL HTTPS absolutas
/// o protocol-relative, sin credenciales ni esquemas ejecutables.
String _safeAgendaImageUrl(dynamic value) {
  if (value is List) {
    for (final item in value) {
      final candidate = _safeAgendaImageUrl(item);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }
  if (value is Map) {
    for (final key in <String>[
      'url', 'contentUrl', 'thumbnailUrl', 'src', 'image',
      'logo', 'crest', 'badge', 'photo', 'picture', 'avatar', 'href',
    ]) {
      final candidate = _safeAgendaImageUrl(value[key]);
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
      return '';
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
// Versión EPG predeterminada anterior: se migra solo si el usuario no
// personalizó la lista de guías.
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

// Fuentes automáticas: primero catálogos en español y emisoras públicas;
// después directorios deportivos internacionales como respaldo.
const String defaultAutoLivePlaylistUrls =
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

const String previousDefaultAutoLiveEpgUrlV2 =
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
    'https://iptv-epg.org/files/epg-do.xml\n'
    'https://iptv-epg.org/files/epg-sv.xml\n'
    'https://iptv-epg.org/files/epg-pt.xml\n'
    'https://iptv-epg.org/files/epg-gb.xml\n'
    'https://iptv-epg.org/files/epg-br.xml\n'
    'https://raw.githubusercontent.com/teleonline/listas/main/epg.xml.gz\n'
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz';

// La guía internacional unificada se combina con una guía deportiva y otra latina.
// Ninguna fuente pública garantiza el 100 % de canales o regiones.
const String previousDefaultAutoLiveEpgUrlV3 =
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
    'https://iptv-epg.org/files/epg-do.xml\n'
    'https://iptv-epg.org/files/epg-sv.xml\n'
    'https://iptv-epg.org/files/epg-pt.xml\n'
    'https://iptv-epg.org/files/epg-gb.xml\n'
    'https://iptv-epg.org/files/epg-br.xml\n'
    'https://raw.githubusercontent.com/teleonline/listas/main/epg.xml.gz\n'
    'https://dearbulut.github.io/iptv/epg/guide.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/Latino_lite.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/US_lite.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/UK_lite.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/Sports_guide.xml.gz';

const String defaultAutoLiveEpgUrl =
    'https://teleonline.github.io/epg/epg.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/Sports_guide.xml.gz\n'
    'https://raw.githubusercontent.com/acidjesuz/EPGTalk/master/Latino_lite.xml.gz';

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

    // Migra la configuración predeterminada anterior sin sobrescribir listas
    // o guías personalizadas que el usuario haya guardado.
    if (playlist.trim() == legacyDefaultAutoLivePlaylistUrls.trim()) {
      playlist = defaultAutoLivePlaylistUrls;
      await prefs.setString(_playlistUrlKey, playlist);
    }
    if (epg.trim() == legacyDefaultAutoLiveEpgUrl.trim() ||
        epg.trim() == previousDefaultAutoLiveEpgUrl.trim() ||
        epg.trim() == previousDefaultAutoLiveEpgUrlV2.trim() ||
        epg.trim() == previousDefaultAutoLiveEpgUrlV3.trim()) {
      epg = defaultAutoLiveEpgUrl;
    }

    // Las guías integradas siempre se cargan automáticamente. Las direcciones
    // personalizadas guardadas en versiones anteriores se conservan y se
    // combinan sin duplicados, sin exponer la lista de EPG en el panel privado.
    final automaticEpgUrls = _splitPlaylistUrls(defaultAutoLiveEpgUrl);
    // Retira antiguas guías integradas, aunque se guardara una URL propia
    // junto a ellas; las fuentes personalizadas se conservan.
    final retiredBuiltInEpgUrls = <String>{
      ..._splitPlaylistUrls(legacyDefaultAutoLiveEpgUrl),
      ..._splitPlaylistUrls(previousDefaultAutoLiveEpgUrl),
      ..._splitPlaylistUrls(previousDefaultAutoLiveEpgUrlV2),
      ..._splitPlaylistUrls(previousDefaultAutoLiveEpgUrlV3),
    };
    final savedEpgUrls = _splitPlaylistUrls(epg)
        .where(isSafeHttpUrl)
        .where((url) => !retiredBuiltInEpgUrls.contains(url));
    epg = <String>{...automaticEpgUrls, ...savedEpgUrls}.join('\n');
    if (prefs.getString(_epgUrlKey) != epg) {
      await prefs.setString(_epgUrlKey, epg);
    }

    // Recupera automáticamente la configuración integrada si una versión
    // anterior dejó valores vacíos, incompletos o con URLs inválidas.
    if (playlist.trim().isEmpty ||
        !_splitPlaylistUrls(playlist).every(isSafeHttpUrl)) {
      playlist = defaultAutoLivePlaylistUrls;
      await prefs.setString(_playlistUrlKey, playlist);
    }
    if (epg.trim().isEmpty ||
        !_splitPlaylistUrls(epg).every(isSafeHttpUrl)) {
      epg = defaultAutoLiveEpgUrl;
      await prefs.setString(_epgUrlKey, epg);
    }

    return AutoLiveSettings(
      playlistUrl: playlist,
      epgUrl: epg,
      authorizationConfirmed: true,
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
    final imageUrl = _safeAgendaImageUrl(
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


/// Normaliza los formatos habituales de una lista de emisoras devuelta por
/// un proveedor deportivo: strings, listas y objetos {name/channel/network}.
List<String> parseBroadcastChannelNames(dynamic value) {
  final names = <String>{};

  void add(dynamic item) {
    if (item == null) return;
    if (item is String) {
      for (final part in item.split(RegExp(r'[|;,\\s]+'))) {
        final name = part.trim();
        if (name.isNotEmpty) names.add(name);
      }
      return;
    }
    if (item is List) {
      for (final child in item) {
        add(child);
      }
      return;
    }
    if (item is Map) {
      final row = Map<String, dynamic>.from(item);
      final name = (row['name'] ?? row['channel'] ?? row['network'] ??
              row['broadcaster'] ?? row['title'] ?? row['station'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) {
        names.add(name);
        return;
      }
      for (final key in const <String>[
        'channels', 'networks', 'broadcasters', 'broadcasts', 'items',
      ]) {
        if (row.containsKey(key)) add(row[key]);
      }
    }
  }

  add(value);
  return names.toList(growable: false);
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
    this.broadcastChannels = const <String>[],
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

  /// Canales de TV declarados por el proveedor del evento, si el proveedor
  /// ofrece ese dato. No se infieren ni se inventan cuando falta.
  final List<String> broadcastChannels;

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
    'broadcastChannels': broadcastChannels,
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
    final rawBroadcastChannels = row['broadcastChannels'] ??
        row['tvChannels'] ?? row['broadcasters'] ??
        row['broadcasts'] ?? row['networks'] ?? row['television'];
    final homeTeam = (row['homeTeam'] ?? '').toString();
    final awayTeam = (row['awayTeam'] ?? '').toString();
    final homeLogo = _safeAgendaImageUrl(
      row['homeTeamLogo'] ?? row['homeTeamLogoUrl'] ?? row['homeLogo'],
    );
    final awayLogo = _safeAgendaImageUrl(
      row['awayTeamLogo'] ?? row['awayTeamLogoUrl'] ?? row['awayLogo'],
    );
    final eventImage = _safeAgendaImageUrl(
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
      broadcastChannels: parseBroadcastChannelNames(rawBroadcastChannels),
    );
  }
}

class SportsAgendaStore {
  static const String _key = 'dt360_sportsapi_agenda_events_v1';
  static const String _windowCompleteKeyPrefix =
      'dt360_sportsapi_agenda_window_complete_v1_';
  static const String _windowSavedAtKeyPrefix =
      'dt360_sportsapi_agenda_window_saved_at_v1_';

  static String _windowCompleteKey(DateTime value) =>
      _windowCompleteKeyPrefix + _dayKey(value);

  static String _windowSavedAtKey(DateTime value) =>
      _windowSavedAtKeyPrefix + _dayKey(value);

  static String _dayKey(DateTime value) {
    final local = value.toLocal();
    return local.year.toString().padLeft(4, '0') + '-' +
        local.month.toString().padLeft(2, '0') + '-' +
        local.day.toString().padLeft(2, '0');
  }

  /// Lee solo los eventos de la jornada local solicitada.
  static Future<List<SportsAgendaEvent>> loadWindow({
    required DateTime startDate,
    int days = 1,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = start.add(Duration(days: days.clamp(1, 7).toInt()));
    return (await load()).where((event) {
      final localStart = event.startsAt.toLocal();
      return !localStart.isBefore(start) && localStart.isBefore(end);
    }).toList(growable: false)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  /// Una copia diaria se considera vigente hasta el final del día salvo que
  /// el usuario solicite una actualización manual.
  static Future<bool> isWindowFresh({
    required DateTime startDate,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Solo una captura confirmada como completa puede evitar la consulta
      // diaria. Las APK anteriores no tienen esta marca y se actualizarán
      // una vez tras instalar esta corrección.
      if (!(prefs.getBool(_windowCompleteKey(startDate)) ?? false)) {
        return false;
      }
      final savedAt = DateTime.tryParse(
        prefs.getString(_windowSavedAtKey(startDate)) ?? '',
      );
      if (savedAt == null) return false;
      final age = DateTime.now().difference(savedAt);
      return !age.isNegative && age <= maxAge;
    } catch (_) {
      return false;
    }
  }

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

  /// Sustituye solamente las fechas incluidas y conserva las demás jornadas
  /// que ya están guardadas para que actualizar hoy no borre mañana.
  static Future<void> saveWindow(
    List<SportsAgendaEvent> events, {
    required DateTime startDate,
    int days = 7,
    bool complete = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final safeDays = days.clamp(1, 7).toInt();
    final end = start.add(Duration(days: safeDays));
    final cutoff = DateTime.now().subtract(const Duration(hours: 4));
    final byId = <String, SportsAgendaEvent>{};

    String dayKey(DateTime value) {
      final local = value.toLocal();
      return local.year.toString() + '-' +
          local.month.toString() + '-' + local.day.toString();
    }

    final replacedDays = <String>{
      for (var index = 0; index < safeDays; index++)
        dayKey(start.add(Duration(days: index))),
    };

    for (final event in await load()) {
      final localStart = event.startsAt.toLocal();
      final eventEnd =
          event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      final eventBelongsToReplacedDay =
          replacedDays.contains(dayKey(localStart));

      // Una respuesta parcial no sabe qué otros deportes/ligas faltan.
      // Conserva por eso los eventos anteriores del mismo día y deja que los
      // nuevos datos sustituyan solo los identificadores que sí llegaron.
      if (eventBelongsToReplacedDay && complete) continue;
      if (eventEnd.isAfter(cutoff)) byId[event.id] = event;
    }

    for (final event in events) {
      final localStart = event.startsAt.toLocal();
      final eventEnd =
          event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      if (localStart.isBefore(start) || !localStart.isBefore(end)) continue;
      if (eventEnd.isAfter(cutoff)) byId[event.id] = event;
    }

    await prefs.setString(
      _key,
      jsonEncode(byId.values.map((event) => event.toJson()).toList()),
    );

    // La marca se almacena por fecha para que otra pantalla (por ejemplo,
    // Estadísticas) no invalide ni certifique accidentalmente la jornada de hoy.
    final completeKey = _windowCompleteKey(start);
    final savedAtKey = _windowSavedAtKey(start);
    if (complete) {
      await prefs.setBool(completeKey, true);
      await prefs.setString(savedAtKey, DateTime.now().toIso8601String());
    } else {
      await prefs.setBool(completeKey, false);
      await prefs.remove(savedAtKey);
    }
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
  });
  final String name;
  final String url;
  final String tvgId;
  final String tvgName;
  final String group;
  final String logo;
  final String language;
  final String country;

  /// 2 = español, 1 = inglés y 0 = idioma sin confirmar.
  int get languagePriority {
    final explicit = language.trim().toLowerCase();
    if (const <String>{'es', 'spa', 'spanish', 'espanol'}.contains(explicit)) return 2;
    if (const <String>{'en', 'eng', 'english'}.contains(explicit)) return 1;
    final metadata = AutomaticLiveService.normalizeText(
      '$language $country $group $name $tvgName',
    );
    const spanishMarkers = <String>[
      'spanish', 'espanol', 'castellano', 'espana', 'spain',
      'mexico', 'argentina', 'colombia', 'venezuela', 'chile',
      'peru', 'uruguay', 'paraguay', 'bolivia', 'ecuador',
      'costa rica', 'guatemala', 'honduras', 'nicaragua',
      'panama', 'dominicana', 'puerto rico', 'teledeporte',
      'esport 3', 'etb deportes', 'real madrid tv', 'betis tv',
    ];
    const englishMarkers = <String>[
      'english', 'united kingdom', 'great britain',
      'sky sports', 'bt sport', 'nbc sports', 'cbs sports network',
      'espn uk', 'tnt sports uk',
    ];
    if (spanishMarkers.any(metadata.contains) ||
        RegExp(r'(^| )(es|spa)( |$)').hasMatch(metadata)) return 2;
    if (englishMarkers.any(metadata.contains) ||
        RegExp(r'(^| )(en|eng)( |$)').hasMatch(metadata)) return 1;
    return 0;
  }
}

class XmltvProgramme {
  const XmltvProgramme({
    required this.channelId, required this.title,
    required this.startsAt, required this.endsAt,
    this.channelName = '',
    this.subtitle = '',
    this.description = '',
  });
  final String channelId;
  final String channelName;
  final String title;
  final String subtitle;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
}

class _EpgSourceCacheEntry {
  const _EpgSourceCacheEntry({
    required this.body,
    required this.fetchedAt,
    required this.lastAttemptAt,
  });
  final String? body;
  final DateTime? fetchedAt;
  final DateTime? lastAttemptAt;
}

class ScheduledLiveSource {
  const ScheduledLiveSource({
    required this.channelName, required this.url,
    required this.programmeTitle, required this.programmeEndsAt,
    required this.qualityScore,
    this.languagePriority = 0,
    this.available = false,
    this.verified = false,
  });
  final String channelName;
  final String url;
  final String programmeTitle;
  final DateTime programmeEndsAt;
  final int qualityScore;
  final int languagePriority;
  final bool available;
  final bool verified;
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

/// Diagnóstico de cada etapa del asignador automático de transmisiones.
class AutoLiveProgress {
  const AutoLiveProgress({
    required this.stage,
    required this.message,
    this.eventCount = 0,
    this.channelCount = 0,
    this.directChannelCount = 0,
    this.programmeCount = 0,
    this.matchedEventCount = 0,
    this.candidateCount = 0,
    this.testedCandidateCount = 0,
    this.availableCandidateCount = 0,
  });

  final String stage;
  final String message;
  final int eventCount;
  final int channelCount;
  final int directChannelCount;
  final int programmeCount;
  final int matchedEventCount;
  final int candidateCount;
  final int testedCandidateCount;
  final int availableCandidateCount;
}

class AutomaticLiveService {
  AutomaticLiveService({
    http.Client? client,
    Future<Directory> Function()? epgCacheDirectoryProvider,
  })  : _client = client ?? http.Client(),
        _epgCacheDirectoryProvider =
            epgCacheDirectoryProvider ?? _defaultEpgCacheDirectory;

  final http.Client _client;
  final Future<Directory> Function() _epgCacheDirectoryProvider;
  final Map<String, Future<String?>> _epgSourceInFlight = <String, Future<String?>>{};

  static const Duration _epgFreshTtl = Duration(minutes: 10);
  static const Duration _epgFailureCooldown = Duration(minutes: 5);
  static const Duration _epgStaleMaxAge = Duration(days: 3);
  static const int _maxEpgCacheBytes = 24 * 1024 * 1024;

  static Future<Directory> _defaultEpgCacheDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/dt360_epg_cache');
    await directory.create(recursive: true);
    return directory;
  }

  static String _epgCacheId(String url) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(url)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  Future<_EpgSourceCacheEntry?> _readEpgSourceCache(String url) async {
    try {
      final directory = await _epgCacheDirectoryProvider();
      final id = _epgCacheId(url);
      final metadataFile = File('${directory.path}/$id.json');
      final bodyFile = File('${directory.path}/$id.xml.gz');
      if (!await metadataFile.exists()) return null;
      final metadata = jsonDecode(await metadataFile.readAsString());
      if (metadata is! Map || metadata['url'] != url) return null;
      final fetchedAt = DateTime.tryParse((metadata['fetchedAt'] ?? '').toString());
      final lastAttemptAt = DateTime.tryParse((metadata['lastAttemptAt'] ?? '').toString());
      String? body;
      if (await bodyFile.exists()) {
        final compressed = await bodyFile.readAsBytes();
        if (compressed.length > _maxEpgCacheBytes) return null;
        final expanded = gzip.decode(compressed);
        if (expanded.length > _maxEpgCacheBytes) return null;
        final decoded = utf8.decode(expanded, allowMalformed: true);
        if (decoded.trim().isNotEmpty) body = decoded;
      }
      return _EpgSourceCacheEntry(
        body: body,
        fetchedAt: fetchedAt,
        lastAttemptAt: lastAttemptAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeEpgSourceCache(
    String url, {
    required DateTime? fetchedAt,
    required DateTime lastAttemptAt,
    String? body,
  }) async {
    try {
      final directory = await _epgCacheDirectoryProvider();
      final id = _epgCacheId(url);
      await directory.create(recursive: true);
      if (body != null) {
        final compressed = gzip.encode(utf8.encode(body));
        if (compressed.length <= _maxEpgCacheBytes) {
          final bodyFile = File('${directory.path}/$id.xml.gz');
          final temporaryBody = File('${directory.path}/$id.xml.gz.tmp');
          await temporaryBody.writeAsBytes(compressed, flush: true);
          if (await bodyFile.exists()) await bodyFile.delete();
          await temporaryBody.rename(bodyFile.path);
        }
      }
      final metadataFile = File('${directory.path}/$id.json');
      final temporaryMetadata = File('${directory.path}/$id.json.tmp');
      await temporaryMetadata.writeAsString(
        jsonEncode(<String, String>{
          'url': url,
          'fetchedAt': fetchedAt?.toIso8601String() ?? '',
          'lastAttemptAt': lastAttemptAt.toIso8601String(),
        }),
        flush: true,
      );
      if (await metadataFile.exists()) await metadataFile.delete();
      await temporaryMetadata.rename(metadataFile.path);
    } catch (_) {
      // Si el almacenamiento falla, las fuentes todavía pueden descargarse.
    }
  }

  Future<String?> _loadEpgSource(String url, {required bool forceRefresh}) {
    final pending = _epgSourceInFlight[url];
    if (pending != null) return pending;
    final operation = () async {
      final now = DateTime.now();
      final cached = await _readEpgSourceCache(url);
      final cachedAge = cached?.fetchedAt == null ? null : now.difference(cached!.fetchedAt!);
      if (!forceRefresh && cached?.body != null && cachedAge != null &&
          !cachedAge.isNegative && cachedAge <= _epgFreshTtl) {
        return cached!.body;
      }
      final lastAttemptAge = cached?.lastAttemptAt == null
          ? null
          : now.difference(cached!.lastAttemptAt!);
      if (!forceRefresh && lastAttemptAge != null &&
          !lastAttemptAge.isNegative && lastAttemptAge < _epgFailureCooldown) {
        return cached?.body;
      }
      try {
        final body = await _downloadText(
          url,
          maxBytes: _maxEpgCacheBytes,
          timeout: const Duration(seconds: 12),
        );
        await _writeEpgSourceCache(
          url,
          fetchedAt: now,
          lastAttemptAt: now,
          body: body,
        );
        return body;
      } catch (_) {
        await _writeEpgSourceCache(
          url,
          fetchedAt: cached?.fetchedAt,
          lastAttemptAt: now,
        );
        if (cached?.body != null && cachedAge != null &&
            !cachedAge.isNegative && cachedAge <= _epgStaleMaxAge) {
          return cached!.body;
        }
        return null;
      }
    }();
    _epgSourceInFlight[url] = operation;
    return operation.whenComplete(() {
      if (identical(_epgSourceInFlight[url], operation)) {
        _epgSourceInFlight.remove(url);
      }
    });
  }

  AutoLiveCatalog? _cachedCatalog;
  DateTime? _cachedAt;
  String? _cachedPlaylist;
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
      // Un snapshot stale no debe imponerse al cálculo local: puede contener
      // una URL que dejó de responder durante la caída del cron.
      if (status != 'ok') return null;
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
        String safeLogo(dynamic value) => _safeAgendaImageUrl(value);
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
              : '',
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
              verified: source['verified'] != false,
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
    required String playlistUrl, required String epgUrl,
    List<M3uChannel>? availableChannels,
    bool forceRefresh = false,
    DateTime? programmeWindowStart,
    DateTime? programmeWindowEnd,
  }) async {
    final playlistUrls = _splitPlaylistUrls(playlistUrl);
    final epgUrls = _splitPlaylistUrls(epgUrl);
    if ((availableChannels == null &&
            (playlistUrls.isEmpty || !playlistUrls.every(isSafeHttpUrl))) ||
        epgUrls.isEmpty ||
        !epgUrls.every(isSafeHttpUrl)) {
      throw const FormatException('Configura una guía XMLTV/EPG válida y canales deportivos seleccionados.');
    }
    final playlistCacheKey = availableChannels == null
        ? playlistUrls.join('\n')
        : 'selected-catalog:' + availableChannels.map((channel) =>
            <String>[channel.tvgId, channel.name, channel.url, channel.language].join('|'),
          ).join('\n');
    final epgCacheKey = epgUrls.join('\n');
    final now = DateTime.now();
    final cached = _cachedCatalog;
    if (!forceRefresh && cached != null &&
        _cachedPlaylist == playlistCacheKey && _cachedEpg == epgCacheKey &&
        _cachedAt != null && now.difference(_cachedAt!) < const Duration(minutes: 2)) {
      return cached;
    }

    final channelsByUrl = <String, M3uChannel>{};
    if (availableChannels != null) {
      // Utiliza exclusivamente los canales visibles/deportivos publicados
      // desde Ajustes > Damián APK; no consulta listas IPTV ajenas.
      for (final channel in availableChannels) {
        if (isDirectPlayableStream(channel.url)) {
          channelsByUrl.putIfAbsent(channel.url, () => channel);
        }
      }
    } else {
      // Compatibilidad con el modo anterior, que todavía puede leer M3U.
      for (var batchStart = 0; batchStart < playlistUrls.length; batchStart += 3) {
        final batch = playlistUrls.skip(batchStart).take(3).toList(growable: false);
        final playlistBodies = await Future.wait<String?>(
          batch.map((url) async {
            try {
              return await _downloadText(url, maxBytes: 12 * 1024 * 1024,
                timeout: const Duration(seconds: 18));
            } catch (_) { return null; }
          }),
        );
        for (var index = 0; index < playlistBodies.length; index++) {
          final body = playlistBodies[index];
          if (body == null) continue;
          final baseUri = Uri.tryParse(batch[index]);
          for (final channel in parseM3u(body, baseUri: baseUri)) {
            channelsByUrl.putIfAbsent(channel.url, () => channel);
          }
        }
      }
    }
    if (availableChannels == null && cached != null &&
        _cachedPlaylist == playlistCacheKey && _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(hours: 12)) {
      for (final channel in cached.channels) {
        channelsByUrl.putIfAbsent(channel.url, () => channel);
      }
    }
    final channels = channelsByUrl.values.toList(growable: false);
    if (channels.isEmpty) {
      if (availableChannels == null) {
        throw const FormatException('No respondió ninguna lista M3U compatible.');
      }
      final empty = AutoLiveCatalog(channels: const <M3uChannel>[],
        programmes: const <XmltvProgramme>[]);
      _cachedCatalog = empty;
      _cachedAt = now;
      _cachedPlaylist = playlistCacheKey;
      _cachedEpg = epgCacheKey;
      return empty;
    }
    // Descarga en lotes pequeños y analiza el XML fuera del isolate de interfaz.
    // Cada lote se libera antes de descargar el siguiente para controlar RAM.
    final programmesByKey = <String, XmltvProgramme>{};
    for (var batchStart = 0; batchStart < epgUrls.length; batchStart += 3) {
      final batch = epgUrls.skip(batchStart).take(3).toList(growable: false);
      final bodies = await Future.wait<String?>(
        batch.map((url) => _loadEpgSource(
          url,
          forceRefresh: forceRefresh,
        )),
      );
      final batchBodies = bodies.whereType<String>().toList(growable: false);
      if (batchBodies.isEmpty) continue;
      final parsed = await Isolate.run<List<XmltvProgramme>>(() {
        final result = <XmltvProgramme>[];
        for (final body in batchBodies) {
          try {
            result.addAll(AutomaticLiveService.parseXmltv(
              body,
              windowStart: programmeWindowStart,
              windowEnd: programmeWindowEnd,
            ));
          } catch (_) {
            // Una guía inválida no interrumpe las demás fuentes.
          }
        }
        return result;
      });
      for (final programme in parsed) {
        final key = <String>[
          programme.channelId.toLowerCase(),
          programme.title.toLowerCase().trim(),
          programme.startsAt.toUtc().toIso8601String(),
          programme.endsAt.toUtc().toIso8601String(),
        ].join('|');
        programmesByKey.putIfAbsent(key, () => programme);
      }
    }
    // La guía es complementaria: si las fuentes EPG fallan, el catálogo de
    // canales sigue disponible y la guía se volverá a intentar en otra carga.
    final programmes = programmesByKey.values.toList(growable: false);

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
    var bytes = compressed.takeBytes();
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        final expanded = BytesBuilder(copy: false);
        var expandedLength = 0;
        await for (final chunk in gzip.decoder
            .bind(Stream<List<int>>.value(bytes))
            .timeout(timeout)) {
          expandedLength += chunk.length;
          if (expandedLength > maxBytes) {
            throw const FormatException('El XML descomprimido supera el límite permitido.');
          }
          expanded.add(chunk);
        }
        bytes = expanded.takeBytes();
      } catch (error) {
        if (error is FormatException) rethrow;
        throw const FormatException('No se pudo descomprimir la fuente GZIP.');
      }
    }
    final body = utf8.decode(bytes, allowMalformed: true);
    if (body.trim().isEmpty) throw const FormatException('La fuente está vacía.');
    return body;
  }

  static List<M3uChannel> parseM3u(String body, {Uri? baseUri}) {
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
      ));
      pending = null;
      pendingName = '';
    }
    return result;
  }

  static List<XmltvProgramme> parseXmltv(
    String body, {
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    final document = XmlDocument.parse(body);
    final channelNames = <String, String>{};
    for (final channel in document.findAllElements('channel')) {
      final id = (channel.getAttribute('id') ?? '').trim();
      final display = channel
          .findElements('display-name')
          .map((node) => node.innerText.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .join(' | ');
      if (id.isNotEmpty && display.isNotEmpty) channelNames[id] = display;
    }
    final result = <XmltvProgramme>[];
    for (final element in document.findAllElements('programme')) {
      final channel = (element.getAttribute('channel') ?? '').trim();
      final start = parseXmltvDate(element.getAttribute('start'));
      final stop = parseXmltvDate(element.getAttribute('stop'));
      final titleNodes = element.findElements('title');
      final subtitleNodes = element.findElements('sub-title');
      final descriptionNodes = element.findElements('desc');
      final title = titleNodes.isEmpty ? '' : titleNodes.first.innerText.trim();
      final subtitle = subtitleNodes.isEmpty
          ? ''
          : subtitleNodes.map((node) => node.innerText.trim())
              .where((value) => value.isNotEmpty).join(' ');
      final description = descriptionNodes.isEmpty
          ? ''
          : descriptionNodes.map((node) => node.innerText.trim())
              .where((value) => value.isNotEmpty).join(' ');
      if (channel.isEmpty || title.isEmpty || start == null ||
          stop == null || !stop.isAfter(start)) continue;
      if (windowStart != null && !stop.isAfter(windowStart)) continue;
      if (windowEnd != null && !start.isBefore(windowEnd)) continue;
      result.add(XmltvProgramme(
        channelId: channel,
        channelName: channelNames[channel] ?? '',
        title: title,
        subtitle: subtitle,
        description: description,
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
    required DateTime now,
    required AutoLiveSettings settings,
    List<M3uChannel>? availableChannels,
    bool forceRefresh = false,
    void Function(AutoLiveProgress progress)? onProgress,
  }) async {
    var channelCount = availableChannels?.length ?? 0;
    var directChannelCount = 0;
    var programmeCount = 0;
    var matchedEventCount = 0;
    var candidateCount = 0;
    var testedCandidateCount = 0;
    var availableCandidateCount = 0;

    void report(String stage, String message) {
      onProgress?.call(AutoLiveProgress(
        stage: stage,
        message: message,
        eventCount: events.length,
        channelCount: channelCount,
        directChannelCount: directChannelCount,
        programmeCount: programmeCount,
        matchedEventCount: matchedEventCount,
        candidateCount: candidateCount,
        testedCandidateCount: testedCandidateCount,
        availableCandidateCount: availableCandidateCount,
      ));
    }

    report('starting', 'Iniciando comprobación de eventos y canales.');
    if (events.isEmpty) {
      report('agenda_empty', 'La Agenda no entregó eventos para hoy. Revisa la carga de SportAPI.');
      return <ScheduledLiveEvent>[];
    }
    if (settings.epgUrls.isEmpty || !settings.epgUrls.every(isSafeHttpUrl)) {
      report('epg_config_missing', 'No hay guías EPG válidas configuradas para buscar programas.');
      return <ScheduledLiveEvent>[];
    }
    if (availableChannels == null && !settings.isConfigured) {
      report('configuration_missing', 'La configuración de canales y guías no está completa.');
      return <ScheduledLiveEvent>[];
    }

    final directChannels = availableChannels
        ?.where((channel) => isDirectPlayableStream(channel.url))
        .toList(growable: false);
    if (availableChannels != null) {
      channelCount = availableChannels.length;
      directChannelCount = directChannels!.length;
      if (directChannels.isEmpty) {
        report('channels_empty', 'No hay canales deportivos visibles con una URL directa compatible. Revisa la selección en Damián APK.');
        return <ScheduledLiveEvent>[];
      }
    }

    final eligibleEvents = events.where((event) {
      final prepareAt = event.startsAt.subtract(const Duration(minutes: 10));
      final eventLimit = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      return !now.isBefore(prepareAt) && now.isBefore(eventLimit);
    }).toList(growable: false);
    if (eligibleEvents.isEmpty) {
      report('outside_window', 'Hay eventos en Agenda, pero ninguno está dentro de la ventana de preparación (10 minutos antes del inicio hasta el final).');
      return <ScheduledLiveEvent>[];
    }

    final programmeWindowStart = events
        .map((event) => event.startsAt.subtract(const Duration(minutes: 30)))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final programmeWindowEnd = events
        .map((event) => (event.endsAt ??
            event.startsAt.add(const Duration(hours: 3))).add(const Duration(minutes: 30)))
        .reduce((a, b) => a.isAfter(b) ? a : b);

    report('loading_guides', 'Cargando las guías EPG guardadas o actualizadas para los horarios de hoy.');
    final catalog = await loadCatalog(
      playlistUrl: settings.playlistUrl,
      epgUrl: settings.epgUrl,
      availableChannels: directChannels,
      forceRefresh: forceRefresh,
      programmeWindowStart: programmeWindowStart,
      programmeWindowEnd: programmeWindowEnd,
    );
    channelCount = catalog.channels.length;
    directChannelCount = catalog.channels.where(
      (channel) => isDirectPlayableStream(channel.url),
    ).length;
    programmeCount = catalog.programmes.length;
    if (catalog.channels.isEmpty) {
      report('channels_empty', 'Las guías respondieron, pero no quedó ningún canal directo válido para asociar.');
      return <ScheduledLiveEvent>[];
    }
    if (catalog.programmes.isEmpty) {
      report('epg_empty', 'Se encontraron canales, pero ninguna guía EPG entregó programas. No se puede asociar una señal por horario solamente.');
      return <ScheduledLiveEvent>[];
    }

    final byId = <String, List<M3uChannel>>{};
    final byName = <String, List<M3uChannel>>{};
    for (final channel in catalog.channels) {
      if (channel.tvgId.isNotEmpty) {
        final id = normalizeText(channel.tvgId);
        if (id.isNotEmpty) byId.putIfAbsent(id, () => <M3uChannel>[]).add(channel);
      }
      for (final rawName in <String>[channel.name, channel.tvgName, channel.tvgId]) {
        for (final name in <String>{normalizeText(rawName), normalizeChannelName(rawName)}) {
          if (name.isEmpty) continue;
          byName.putIfAbsent(name, () => <M3uChannel>[]).add(channel);
          final compactName = name.replaceAll(' ', '');
          if (compactName.isNotEmpty) byName.putIfAbsent(compactName, () => <M3uChannel>[]).add(channel);
        }
      }
    }

    report('matching_epg', 'Buscando coincidencias entre los programas EPG y los eventos de Agenda.');
    final output = <ScheduledLiveEvent>[];
    for (final event in eligibleEvents) {
      final prepareAt = event.startsAt.subtract(const Duration(minutes: 10));
      final eventLimit = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
      // Prioridad 1: coincidencia estricta por equipos/participantes.
      // Algunas EPG solo publican etiquetas genéricas aunque el programa esté
      // asignado al canal deportivo correcto y al horario del evento.
      final overlappingProgrammes = catalog.programmes.where((programme) =>
        programme.startsAt.isBefore(eventLimit) &&
        programme.endsAt.isAfter(prepareAt)).toList(growable: false);
      final exactProgrammes = overlappingProgrammes.where((programme) =>
        programmeMatchesEvent(
          '${programme.title} ${programme.subtitle} ${programme.description}',
          event,
        )).toList(growable: false);
      final programmes = (exactProgrammes.isNotEmpty
          ? exactProgrammes
          : overlappingProgrammes.where((programme) =>
              !_isExplicitDifferentFixture(
                '${programme.title} ${programme.subtitle} ${programme.description}',
              )).toList(growable: false))
        .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (programmes.isNotEmpty) matchedEventCount++;

      final candidates = <ScheduledLiveSource>[];
      final used = <String>{};
      for (final programme in programmes) {
        final channelNameAliases = programme.channelName
            .split('|')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        final mapped = <M3uChannel>[
          ...(byId[normalizeText(programme.channelId)] ?? <M3uChannel>[]),
          for (final channelName in channelNameAliases) ...<M3uChannel>[
            ...(byName[normalizeText(channelName)] ?? <M3uChannel>[]),
            ...(byName[normalizeChannelName(channelName)] ?? <M3uChannel>[]),
            ...(byName[normalizeChannelName(channelName).replaceAll(' ', '')] ?? <M3uChannel>[]),
          ],
          ...(byName[normalizeText(programme.channelId)] ?? <M3uChannel>[]),
          ...(byName[normalizeChannelName(programme.channelId)] ?? <M3uChannel>[]),
          ...(byName[normalizeChannelName(programme.channelId).replaceAll(' ', '')] ?? <M3uChannel>[]),
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
      candidateCount += candidates.length;
      if (candidates.isEmpty) continue;

      report('checking_signals', 'Coincidencias EPG encontradas. Comprobando ${candidates.length} señal(es) para este evento.');
      candidates.sort((a, b) {
        final language = b.languagePriority.compareTo(a.languagePriority);
        return language != 0 ? language : b.qualityScore.compareTo(a.qualityScore);
      });
      final verifiedCandidates = <ScheduledLiveSource>[];
      for (var batchStart = 0; batchStart < candidates.length; batchStart += 8) {
        final batch = candidates.skip(batchStart).take(8).toList(growable: false);
        testedCandidateCount += batch.length;
        final checked = await Future.wait<ScheduledLiveSource>(
          batch.map(_probeCandidate),
        );
        final available = checked.where((candidate) => candidate.available).toList(growable: false);
        verifiedCandidates.addAll(available);
        availableCandidateCount += available.length;
        report('checking_signals', 'Señales comprobadas: $testedCandidateCount; reproducibles: $availableCandidateCount.');
      }
      verifiedCandidates.sort((a, b) {
        final language = b.languagePriority.compareTo(a.languagePriority);
        return language != 0 ? language : b.qualityScore.compareTo(a.qualityScore);
      });

      // El sondeo HTTP es orientativo: algunos CDN bloquean GET/Range desde
      // diagnóstico, aunque el reproductor nativo pueda abrir el manifiesto.
      // Conservamos la mejor coincidencia EPG para probarla en el reproductor.
      ScheduledLiveSource nativeFallback(ScheduledLiveSource candidate) =>
          ScheduledLiveSource(
            channelName: candidate.channelName,
            url: candidate.url,
            programmeTitle: candidate.programmeTitle,
            programmeEndsAt: candidate.programmeEndsAt,
            qualityScore: candidate.qualityScore,
            languagePriority: candidate.languagePriority,
            available: true,
            verified: false,
          );

      final sources = <ScheduledLiveSource>[];
      if (verifiedCandidates.isNotEmpty) {
        final spanish = verifiedCandidates.where((item) => item.languagePriority == 2);
        final english = verifiedCandidates.where((item) => item.languagePriority == 1);
        if (spanish.isNotEmpty) sources.add(spanish.first);
        if (english.isNotEmpty) sources.add(english.first);
        // Si solo se conoce otra prioridad de idioma, conserva esa señal.
        if (sources.isEmpty) sources.add(verifiedCandidates.first);
      } else {
        // Solo recurrimos a una URL no verificada si ninguna candidata supera
        // el sondeo. Así no mostramos canales caídos cuando ya existe otro
        // idioma con una señal confirmada.
        sources.add(nativeFallback(candidates.first));
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
    if (output.isNotEmpty) {
      final unverifiedCount = output
          .expand((item) => item.sources)
          .where((source) => !source.verified)
          .length;
      report(
        'ready',
        unverifiedCount == 0
            ? 'Transmisiones preparadas para ${output.length} evento(s).'
            : 'Transmisiones preparadas para ${output.length} evento(s); ${unverifiedCount} señal(es) se comprobarán al abrir el reproductor.',
      );
    } else if (matchedEventCount == 0) {
      report('programme_not_matched', 'La EPG contiene programas, pero sus títulos no coinciden con los equipos o participantes de los eventos actuales.');
    } else if (candidateCount == 0) {
      report('channel_not_mapped', 'Hay programas coincidentes, pero sus identificadores/nombres no enlazan con los canales seleccionados.');
    } else {
      report('signals_unavailable', 'Se encontraron programas y candidatos, pero ninguna URL superó la comprobación de señal. Puede estar caída, bloqueada o no ser un manifiesto directo compatible.');
    }
    return output;
  }

  /// Impide usar por horario una guía que anuncia claramente otro partido.
  static bool _isExplicitDifferentFixture(String value) {
    final normalized = normalizeText(value);
    return RegExp(r'\b(?:vs|versus|v)\b').hasMatch(normalized);
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
    final participantNames = event.participants
        .map((participant) => participant.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (participantNames.isNotEmpty) {
      final matchedParticipants = participantNames.where(
        (name) => _teamMatchesProgramme(name, programme),
      ).length;
      final individualSport = const <String>{
        'mma', 'ufc', 'ciclismo', 'cycling', 'formula 1', 'formula uno',
        'deportes de motor', 'motorsport', 'tenis', 'golf', 'boxeo',
      }.contains(sport);
      final requiredParticipants = individualSport || participantNames.length == 1
          ? 1
          : 2;
      if (matchedParticipants >= requiredParticipants) return true;
    }

    // UFC suele anunciar el evento y no necesariamente ambos luchadores.
    if (sport == 'mma' && competition.isNotEmpty &&
        programme.contains(competition)) {
      return true;
    }

    if (home.isNotEmpty && away.isNotEmpty &&
        _teamMatchesProgramme(home, programme) &&
        _teamMatchesProgramme(away, programme)) {
      return true;
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
        verified: true,
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
      verified: true,
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

  static String normalizeChannelName(String value) {
    var text = normalizeText(value);
    text = text.replaceFirst(
      RegExp(r'^(?:us|uk|gb|ca|mx|ar|co|ve|cl|pe|uy|py|bo|cr|gt|hn|ni|pa|cw|jm|do|sv|pt|br) '),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\b(?:hd|sd|fhd|uhd|4k|8k|1080p|720p|576p|480p|50fps|60fps|hevc|h265)\b'),
      ' ',
    );
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
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
