import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'sports_api_service.dart';

const Color _liveBg = Color(0xFF030814);
const Color _livePanel = Color(0xFF071326);
const Color _livePanel2 = Color(0xFF0B1B31);
const Color _liveLine = Color(0xFF123D65);
const Color _liveCyan = Color(0xFF00E5FF);
const Color _livePink = Color(0xFFFF28CF);
const Color _liveGreen = Color(0xFF39FF9C);
const Color _liveRed = Color(0xFFFF3155);
const Color _liveMuted = Color(0xFFA9BDD6);

const String _savedStreamsKey = 'deporte_total_authorized_live_sources_v1';
const String _savedFavoritesKey = 'deporte_total_live_favorites_v1';

enum LiveFixtureStatus { live, scheduled, finished }

/// Datos del partido que llegan del mismo Worker que alimenta la agenda nativa.
/// Una transmisión nunca se deduce de una página web ni del horario por sí solo.
class LiveFixture {
  const LiveFixture({
    required this.id,
    required this.sport,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.startsAt,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.homeLogo,
    this.awayLogo,
  });

  final String id;
  final String sport;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final DateTime startsAt;
  final LiveFixtureStatus status;
  final int? homeScore;
  final int? awayScore;
  final String? homeLogo;
  final String? awayLogo;

  String get displayTitle => '$homeTeam vs $awayTeam';

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _name(dynamic value) {
    if (value is String) return value.trim();
    final map = _asMap(value);
    final nestedTeam = _asMap(map['team']);
    final fighter = _asMap(map['fighter']);
    return '${map['name'] ?? nestedTeam['name'] ?? fighter['name'] ?? ''}'.trim();
  }

  static int? _score(dynamic value) {
    if (value is Map) {
      final map = _asMap(value);
      value = map['total'] ?? map['score'] ?? map['goals'] ??
          map['runs'] ?? map['points'];
    }
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  static DateTime? _date(dynamic value, [dynamic fallbackTime]) {
    if (value is DateTime) return value.toLocal();
    if (value is num) {
      final stamp = value.toInt();
      final milliseconds = stamp.abs() < 10000000000 ? stamp * 1000 : stamp;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
    }
    if (value is Map) {
      final map = _asMap(value);
      return _date(
        map['start'] ?? map['date'] ?? map['kickoff'] ??
            map['timestamp'] ?? map['time'],
        map['time'] ?? fallbackTime,
      );
    }
    if (value == null) return null;
    var text = value.toString().trim();
    if (text.isEmpty) return null;
    final numeric = int.tryParse(text);
    if (numeric != null && text.length >= 9) {
      final milliseconds = numeric.abs() < 10000000000
          ? numeric * 1000
          : numeric;
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
    if (fallbackTime is String &&
        fallbackTime.trim().isNotEmpty &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      text = '${text}T${fallbackTime.trim()}';
    }
    return DateTime.tryParse(text)?.toLocal();
  }

  static LiveFixture? tryParse(Map<String, dynamic> row, String sport) {
    final fixture = _asMap(row['fixture']);
    final game = _asMap(row['game']);
    final race = _asMap(row['race']);
    final fight = _asMap(row['fight']);
    final league = _asMap(row['league'] ?? game['league'] ?? race['competition']);
    final teams = _asMap(row['teams'] ?? game['teams']);
    final fighters = _asMap(row['fighters'] ?? fight['fighters']);

    final homeRaw = teams['home'] ?? row['home'] ?? game['home'] ??
        fighters['fighter1'] ?? fighters['red'] ?? row['fighter1'] ??
        row['red'] ?? (sport == 'Fórmula 1'
            ? race['competition'] ?? row['competition']
            : null) ?? row['driver'];
    final awayRaw = teams['away'] ?? row['away'] ?? game['away'] ??
        fighters['fighter2'] ?? fighters['blue'] ?? row['fighter2'] ??
        row['blue'] ?? (sport == 'Fórmula 1'
            ? race['circuit'] ?? row['circuit']
            : null);

    var homeName = _name(homeRaw);
    var awayName = _name(awayRaw);
    if (sport == 'Fórmula 1') {
      homeName = homeName.isEmpty
          ? '${race['name'] ?? row['competition'] ?? 'Gran Premio'}'
          : homeName;
      awayName = awayName.isEmpty
          ? '${race['circuit'] ?? row['circuit'] ?? 'Carrera'}'
          : awayName;
    }

    final kickoff = _date(
      fixture['date'] ?? fixture['timestamp'] ?? row['date'] ??
          row['timestamp'] ?? game['date'] ?? game['timestamp'] ??
          fight['date'] ?? fight['timestamp'] ?? race['date'] ??
          race['timestamp'] ?? row['start_date'],
      fixture['time'] ?? game['time'] ?? fight['time'] ??
          race['time'] ?? row['time'],
    );
    if (kickoff == null || homeName.isEmpty || awayName.isEmpty) return null;

    final rawStatus = fixture['status'] ?? row['status'] ?? game['status'];
    final statusMap = _asMap(rawStatus);
    final statusCode = '${statusMap['short'] ?? statusMap['code'] ??
        (rawStatus is String ? rawStatus : '')}'.toUpperCase();
    final statusText = '${statusMap['long'] ?? statusCode}'.toLowerCase();

    const liveCodes = <String>{
      '1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE', 'INT',
      'Q1', 'Q2', 'Q3', 'Q4', 'OT',
      'IN1', 'IN2', 'IN3', 'IN4', 'IN5',
      'IN6', 'IN7', 'IN8', 'IN9', 'INTR',
    };
    const finishedCodes = <String>{
      'FT', 'AET', 'AOT', 'PEN', 'AWD', 'WO', 'CANC', 'ABD',
    };
    final isLive = liveCodes.contains(statusCode) ||
        statusText.contains('in progress') ||
        statusText.contains('in play') ||
        statusText.contains('live');
    final isFinished = finishedCodes.contains(statusCode) ||
        statusText.contains('finished') ||
        statusText == 'final';

    final scoreMap = _asMap(row['goals'] ?? row['scores'] ?? game['scores']);
    final home = _asMap(homeRaw);
    final away = _asMap(awayRaw);
    final homeNested = _asMap(home['team']);
    final awayNested = _asMap(away['team']);
    final homeFighter = _asMap(home['fighter']);
    final awayFighter = _asMap(away['fighter']);
    final eventId = fixture['id'] ?? game['id'] ?? row['id'];
    final id = '${eventId ?? '${sport}_${homeName}_$awayName'}';

    return LiveFixture(
      id: id,
      sport: sport,
      competition: '${league['name'] ?? row['competition'] ??
          race['name'] ?? fight['name'] ?? sport}',
      homeTeam: homeName,
      awayTeam: awayName,
      startsAt: kickoff,
      status: isLive
          ? LiveFixtureStatus.live
          : isFinished
              ? LiveFixtureStatus.finished
              : LiveFixtureStatus.scheduled,
      homeScore: _score(scoreMap['home'] ?? home['score']),
      awayScore: _score(scoreMap['away'] ?? away['score']),
      homeLogo: (home['logo'] ?? homeNested['logo'] ?? homeFighter['photo'])
              is String
          ? (home['logo'] ?? homeNested['logo'] ?? homeFighter['photo']) as String
          : null,
      awayLogo: (away['logo'] ?? awayNested['logo'] ?? awayFighter['photo'])
              is String
          ? (away['logo'] ?? awayNested['logo'] ?? awayFighter['photo']) as String
          : null,
    );
  }
}

/// Solo admite enlaces multimedia directos por HTTP(S); no páginas web,
/// reproductores incrustados, RTMP, DASH ni enlaces con autenticación embebida.
bool isSupportedAuthorizedMediaUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.mp4') || path.endsWith('.ts');
}

class LiveStreamSource {
  const LiveStreamSource({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.sport,
    required this.name,
    required this.url,
    this.isRemote = false,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String sport;
  final String name;
  final String url;
  final bool isRemote;

  Uri? get validatedUri =>
      isSupportedAuthorizedMediaUrl(url) ? Uri.tryParse(url.trim()) : null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'sport': sport,
        'name': name,
        'url': url,
      };

  static LiveStreamSource? fromJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final source = LiveStreamSource(
      id: '${map['id'] ?? ''}',
      eventId: '${map['eventId'] ?? ''}',
      eventTitle: '${map['eventTitle'] ?? ''}',
      sport: '${map['sport'] ?? 'Fútbol'}',
      name: '${map['name'] ?? ''}',
      url: '${map['url'] ?? ''}',
      isRemote: map['isRemote'] == true,
    );
    if (source.id.isEmpty ||
        source.eventId.isEmpty ||
        source.name.isEmpty ||
        source.validatedUri == null) {
      return null;
    }
    return source;
  }

  /// El catálogo remoto solo puede entregar señales directas autorizadas.
  static LiveStreamSource? fromCatalogJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    map['isRemote'] = true;
    return LiveStreamSource.fromJson(map);
  }
}

class LiveChannelsScreen extends StatefulWidget {
  const LiveChannelsScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  static const List<String> _sports = <String>[
    'Todos',
    'Fútbol',
    'Básquet',
    'NBA',
    'Béisbol',
    'Fútbol americano',
    'Hockey sobre hielo',
    'Balonmano',
    'Rugby',
    'Vóley',
    'Fútbol australiano',
    'Fórmula 1',
    'MMA',
  ];

  final SportsApiService _api = SportsApiService();
  final TextEditingController _searchController = TextEditingController();
  final List<LiveFixture> _fixtures = <LiveFixture>[];
  final List<LiveStreamSource> _sources = <LiveStreamSource>[];
  final List<LiveStreamSource> _remoteSources = <LiveStreamSource>[];
  final Set<String> _favorites = <String>{};
  final Set<String> _selectedForMultiView = <String>{};

  String _sport = 'Todos';
  String _dateFilter = 'Todos';
  String _statusFilter = 'Todos';
  String _query = '';
  bool _loading = true;
  String? _error;
  int _requestVersion = 0;
  Timer? _refreshTimer;
  late final VoidCallback _apiUrlListener;

  @override
  void initState() {
    super.initState();
    _apiUrlListener = _onApiUrlChanged;
    sportsApiBaseUrl.addListener(_apiUrlListener);
    _loadSavedConfiguration();
    _loadSchedule(initial: true);
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted && widget.isActive && !_loading) _loadSchedule();
    });
  }

  @override
  void didUpdateWidget(covariant LiveChannelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && !_loading) {
      _loadSchedule();
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _refreshTimer?.cancel();
    sportsApiBaseUrl.removeListener(_apiUrlListener);
    _searchController.dispose();
    super.dispose();
  }

  void _onApiUrlChanged() {
    if (mounted) _loadSchedule();
  }

  Future<void> _loadSavedConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSources = prefs.getString(_savedStreamsKey);
      final decoded = rawSources == null ? null : jsonDecode(rawSources);
      final loadedSources = decoded is List
          ? decoded
              .map(LiveStreamSource.fromJson)
              .whereType<LiveStreamSource>()
              .toList(growable: true)
          : <LiveStreamSource>[];
      final loadedFavorites =
          prefs.getStringList(_savedFavoritesKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _sources
          ..clear()
          ..addAll(loadedSources);
        _favorites
          ..clear()
          ..addAll(loadedFavorites);
      });
    } catch (_) {
      // Un catálogo local dañado no debe impedir abrir la pantalla.
    }
  }

  Future<void> _persistConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _savedStreamsKey,
        jsonEncode(_sources.map((source) => source.toJson()).toList()),
      );
      await prefs.setStringList(_savedFavoritesKey, _favorites.toList());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el catálogo: $error')),
        );
      }
    }
  }

  Future<void> _loadSchedule({bool initial = false}) async {
    final version = ++_requestVersion;
    if (mounted) {
      void prepareLoading() {
        _loading = true;
        _error = null;
      }
      if (initial) {
        prepareLoading();
      } else {
        setState(prepareLoading);
      }
    }
    try {
      final sportErrors = <String, String>{};
      final List<Map<String, dynamic>> rows;
      if (_sport == 'Todos') {
        final partialFixtures = <LiveFixture>[];
        rows = await _api.fetchAllAgendaEvents(
          dateFilter: _dateFilter,
          onSportError: (sport, error) {
            sportErrors[sport] = error.toString();
          },
          onSportComplete: (sport, sportRows) {
            final additions = sportRows
                .map((row) => LiveFixture.tryParse(
                      row,
                      (row['_sportName'] ?? sport).toString(),
                    ))
                .whereType<LiveFixture>();
            partialFixtures.addAll(additions);
            if (mounted && version == _requestVersion) {
              setState(() {
                _fixtures
                  ..clear()
                  ..addAll(partialFixtures);
                _loading = true;
              });
            }
          },
        );
      } else {
        rows = await _api.fetchAgendaEvents(
          sport: _sport,
          dateFilter: _dateFilter,
        );
      }
      final parsed = rows
          .map((row) => LiveFixture.tryParse(
                row,
                (row['_sportName'] ?? _sport).toString(),
              ))
          .whereType<LiveFixture>()
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      // El catálogo procede del Worker del propietario. Se asocia por el ID
      // estable del evento que devuelve la agenda, nunca por una URL capturada
      // de una página externa. Un fallo del catálogo no bloquea la agenda.
      var catalogSources = <LiveStreamSource>[];
      if (_sport != 'Todos') {
        try {
          final catalogRows = await _api.fetchAuthorizedLiveSources(
            sport: _sport,
            dateFilter: _dateFilter,
          );
          final fixtureIds = parsed.map((fixture) => fixture.id).toSet();
          catalogSources = catalogRows
              .map(LiveStreamSource.fromCatalogJson)
              .whereType<LiveStreamSource>()
              .where((source) => fixtureIds.contains(source.eventId))
              .toList(growable: false);
        } catch (_) {
          catalogSources = <LiveStreamSource>[];
        }
      }

      if (!mounted || version != _requestVersion) return;
      setState(() {
        _fixtures
          ..clear()
          ..addAll(parsed);
        _remoteSources
          ..clear()
          ..addAll(catalogSources);
        _loading = false;
        _error = null;
        _selectedForMultiView.removeWhere((id) =>
            !_fixtures.any((fixture) =>
                fixture.id == id &&
                fixture.status == LiveFixtureStatus.live) ||
            _sourcesFor(id).isEmpty);
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _fixtures.clear();
        _remoteSources.clear();
        _selectedForMultiView.clear();
      });
    }
  }

  List<LiveStreamSource> _sourcesFor(String eventId) => <LiveStreamSource>[
        ..._sources.where((source) => source.eventId == eventId),
        ..._remoteSources.where((source) => source.eventId == eventId),
      ];

  List<LiveFixture> get _filteredFixtures {
    final query = _query.trim().toLowerCase();
    return _fixtures.where((fixture) {
      if (_sport != 'Todos' && fixture.sport != _sport) return false;
      if (_statusFilter == 'En vivo' &&
          fixture.status != LiveFixtureStatus.live) {
        return false;
      }
      if (_statusFilter == 'Programados' &&
          fixture.status != LiveFixtureStatus.scheduled) {
        return false;
      }
      if (_statusFilter == 'Finalizados' &&
          fixture.status != LiveFixtureStatus.finished) {
        return false;
      }
      if (query.isNotEmpty &&
          !'${fixture.homeTeam} ${fixture.awayTeam} ${fixture.competition}'
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _toggleFavorite(LiveFixture fixture) async {
    setState(() {
      if (!_favorites.add(fixture.id)) _favorites.remove(fixture.id);
    });
    await _persistConfiguration();
  }

  Future<void> _addAuthorizedSource(LiveFixture fixture) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    var authorizationConfirmed = false;
    var validationError = '';
    final draft = await showDialog<LiveStreamSource>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _livePanel,
          title: const Text(
            'Vincular señal autorizada',
            style: TextStyle(color: _liveCyan, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${fixture.displayTitle}\n${fixture.competition}',
                  style: const TextStyle(color: _liveMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la señal',
                    hintText: 'Ej. Canal oficial / señal principal',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlController,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL directa HLS o MP4',
                    hintText: 'https://servidor-autorizado/stream.m3u8',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: authorizationConfirmed,
                  activeColor: _liveGreen,
                  title: const Text(
                    'Confirmo que tengo autorización para reproducir esta señal.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onChanged: (value) => setDialogState(
                    () => authorizationConfirmed = value ?? false,
                  ),
                ),
                if (validationError.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validationError,
                      style: const TextStyle(color: _liveRed, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 5),
                const Text(
                  'Se aceptan enlaces directos .m3u8 o .mp4. No se extraen enlaces de reproductores web ni se omiten DRM, inicios de sesión o restricciones.',
                  style: TextStyle(color: _liveMuted, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final url = urlController.text.trim();
                if (name.isEmpty || !isSupportedAuthorizedMediaUrl(url)) {
                  setDialogState(() {
                    validationError =
                        'Indica un nombre y una URL directa .m3u8 o .mp4 válida.';
                  });
                  return;
                }
                if (!authorizationConfirmed) {
                  setDialogState(() {
                    validationError = 'Confirma que tienes autorización.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  LiveStreamSource(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    eventId: fixture.id,
                    eventTitle: fixture.displayTitle,
                    sport: fixture.sport,
                    name: name,
                    url: url,
                  ),
                );
              },
              child: const Text('Guardar señal'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (draft == null || !mounted) return;
    setState(() => _sources.add(draft));
    await _persistConfiguration();
  }

  Future<void> _removeSource(LiveStreamSource source) async {
    if (source.isRemote) return;
    setState(() {
      _sources.removeWhere((item) => item.id == source.id);
      if (_sourcesFor(source.eventId).isEmpty) {
        _selectedForMultiView.remove(source.eventId);
      }
    });
    await _persistConfiguration();
  }

  void _toggleMultiView(LiveFixture fixture) {
    final available = _sourcesFor(fixture.id);
    if (fixture.status != LiveFixtureStatus.live || available.isEmpty) return;
    setState(() {
      if (_selectedForMultiView.contains(fixture.id)) {
        _selectedForMultiView.remove(fixture.id);
      } else if (_selectedForMultiView.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La multivista admite hasta cuatro cuadros.')),
        );
      } else {
        _selectedForMultiView.add(fixture.id);
      }
    });
  }

  Future<void> _openSelectedMultiView() async {
    final selected = _fixtures
        .where((fixture) =>
            fixture.status == LiveFixtureStatus.live &&
            _selectedForMultiView.contains(fixture.id))
        .map((fixture) {
          final streams = _sourcesFor(fixture.id);
          if (streams.isEmpty) return null;
          final source = streams.first;
          return LivePlayerSource(
            title: '${fixture.displayTitle} · ${source.name}',
            url: source.url,
          );
        })
        .whereType<LivePlayerSource>()
        .toList(growable: false);
    if (selected.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(sources: selected),
      ),
    );
  }

  Future<void> _openSource(
    LiveFixture fixture,
    LiveStreamSource source,
  ) async {
    if (fixture.status != LiveFixtureStatus.live) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La señal solo se abre cuando el evento está en vivo.')),
        );
      }
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerGridScreen(
          sources: <LivePlayerSource>[
            LivePlayerSource(
              title: '${fixture.displayTitle} · ${source.name}',
              url: source.url,
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(LiveFixture fixture) {
    switch (fixture.status) {
      case LiveFixtureStatus.live:
        return 'EN VIVO';
      case LiveFixtureStatus.finished:
        return 'FINALIZADO';
      case LiveFixtureStatus.scheduled:
        return 'PROGRAMADO';
    }
  }

  Color _statusColor(LiveFixture fixture) {
    switch (fixture.status) {
      case LiveFixtureStatus.live:
        return _liveRed;
      case LiveFixtureStatus.finished:
        return _liveMuted;
      case LiveFixtureStatus.scheduled:
        return _liveGreen;
    }
  }

  String _timeText(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }

  Widget _teamLogo(String? url, IconData fallback) {
    final uri = Uri.tryParse(url ?? '');
    if (uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.network(
          uri.toString(),
          width: 30,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            fallback,
            color: _liveCyan,
            size: 25,
          ),
        ),
      );
    }
    return Icon(fallback, color: _liveCyan, size: 25);
  }

  Widget _fixtureCard(LiveFixture fixture) {
    final streams = _sourcesFor(fixture.id);
    final selected = _selectedForMultiView.contains(fixture.id);
    final favorite = _favorites.contains(fixture.id);
    final statusColor = _statusColor(fixture);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _livePanel.withAlpha(245),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: fixture.status == LiveFixtureStatus.live
              ? _livePink.withAlpha(175)
              : _liveLine,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: statusColor.withAlpha(15), blurRadius: 15),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${fixture.sport.toUpperCase()} · ${fixture.competition}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _liveMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(150)),
                ),
                child: Text(
                  _statusText(fixture),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleFavorite(fixture),
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: favorite ? const Color(0xFFFFD600) : _liveMuted,
                ),
                tooltip: favorite ? 'Quitar favorito' : 'Guardar favorito',
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    _teamLogo(fixture.homeLogo, Icons.sports_soccer_rounded),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        fixture.homeTeam,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Text(
                  fixture.homeScore != null || fixture.awayScore != null
                      ? '${fixture.homeScore ?? '-'} : ${fixture.awayScore ?? '-'}'
                      : 'VS',
                  style: const TextStyle(
                    color: _liveCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        fixture.awayTeam,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _teamLogo(fixture.awayLogo, Icons.sports_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded, color: _liveMuted, size: 14),
              const SizedBox(width: 5),
              Text(
                _timeText(fixture.startsAt),
                style: const TextStyle(color: _liveMuted, fontSize: 10),
              ),
              const Spacer(),
              Text(
                streams.isEmpty
                    ? 'SIN SEÑAL VINCULADA'
                    : '${streams.length} ${streams.length == 1 ? 'SEÑAL' : 'SEÑALES'}',
                style: TextStyle(
                  color: streams.isEmpty ? _liveMuted : _liveGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (streams.isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            for (final source in streams)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.play_circle_outline_rounded,
                        color: _liveCyan, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        source.isRemote
                            ? '${source.name} · CATÁLOGO'
                            : source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: fixture.status == LiveFixtureStatus.live
                          ? () => _openSource(fixture, source)
                          : null,
                      child: const Text('VER'),
                    ),
                    if (!source.isRemote)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeSource(source),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: _liveMuted,
                        size: 18,
                      ),
                      tooltip: 'Quitar señal',
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _addAuthorizedSource(fixture),
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: Text(streams.isEmpty ? 'Vincular señal' : 'Añadir señal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _liveCyan,
                  side: const BorderSide(color: _liveCyan),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (fixture.status == LiveFixtureStatus.live && streams.isNotEmpty)
                FilterChip(
                  selected: selected,
                  onSelected: (_) => _toggleMultiView(fixture),
                  selectedColor: _livePink.withAlpha(45),
                  backgroundColor: _livePanel2,
                  checkmarkColor: _livePink,
                  label: Text(
                    selected ? 'En multivista' : 'Añadir a multivista',
                    style: TextStyle(
                      color: selected ? _livePink : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  side: BorderSide(color: selected ? _livePink : _liveLine),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixtures = _filteredFixtures;
    return Scaffold(
      backgroundColor: _liveBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'DEPORTES EN VIVO',
          style: TextStyle(
            color: _liveCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadSchedule,
            icon: const Icon(Icons.refresh_rounded, color: _liveCyan),
            tooltip: 'Actualizar agenda',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
            decoration: const BoxDecoration(
              color: _livePanel,
              border: Border(bottom: BorderSide(color: _liveLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'PARTIDOS Y SEÑALES',
                  style: TextStyle(
                    color: _livePink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'La agenda indica qué eventos están en juego. Vincula únicamente señales directas que tengas permiso para reproducir.',
                  style: TextStyle(
                    color: _liveMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 37,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sports.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final sport = _sports[index];
                      final selected = _sport == sport;
                      return ChoiceChip(
                        label: Text(sport),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _sport = sport;
                            _selectedForMultiView.clear();
                          });
                          _loadSchedule();
                        },
                        selectedColor: _liveCyan.withAlpha(35),
                        backgroundColor: _livePanel2,
                        labelStyle: TextStyle(
                          color: selected ? _liveCyan : _liveMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        side: BorderSide(
                          color: selected ? _liveCyan : _liveLine,
                        ),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    for (final filter in <String>['Hoy', 'Todos'])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(filter == 'Hoy' ? 'HOY' : 'PRÓXIMOS'),
                          selected: _dateFilter == filter,
                          onSelected: (_) {
                            setState(() {
                              _dateFilter = filter;
                              _selectedForMultiView.clear();
                            });
                            _loadSchedule();
                          },
                          selectedColor: _liveGreen.withAlpha(28),
                          backgroundColor: _livePanel2,
                          labelStyle: TextStyle(
                            color: _dateFilter == filter ? _liveGreen : _liveMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                          side: BorderSide(
                            color: _dateFilter == filter ? _liveGreen : _liveLine,
                          ),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${_fixtures.length} eventos',
                      style: const TextStyle(color: _liveMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar equipo, evento o competición',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  children: <String>['Todos', 'En vivo', 'Programados', 'Finalizados']
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(filter.toUpperCase()),
                          selected: _statusFilter == filter,
                          onSelected: (_) => setState(() => _statusFilter = filter),
                          selectedColor: _livePink.withAlpha(35),
                          backgroundColor: _livePanel2,
                          labelStyle: TextStyle(
                            color: _statusFilter == filter ? _livePink : _liveMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                          side: BorderSide(
                            color: _statusFilter == filter ? _livePink : _liveLine,
                          ),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          if (_selectedForMultiView.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF101329),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_selectedForMultiView.length}/4 cuadros seleccionados',
                      style: const TextStyle(
                        color: _liveCyan,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openSelectedMultiView,
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: const Text('ABRIR MULTIVISTA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _livePink,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSchedule,
              color: _liveCyan,
              backgroundColor: _livePanel,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
                children: <Widget>[
                  if (_loading && _fixtures.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(34),
                      child: Center(
                        child: CircularProgressIndicator(color: _liveCyan),
                      ),
                    )
                  else if (_error != null && _fixtures.isEmpty)
                    _emptyState(
                      Icons.cloud_off_rounded,
                      'NO SE PUDO CARGAR LA AGENDA',
                      '${_error}\n\nComprueba el servidor de estadísticas en Ajustes y vuelve a actualizar.',
                    )
                  else if (fixtures.isEmpty)
                    _emptyState(
                      Icons.event_busy_rounded,
                      'NO HAY EVENTOS PARA ESTE FILTRO',
                      'Prueba otro deporte, cambia el rango de fechas o actualiza la agenda. No se mostrarán partidos inventados.',
                    )
                  else ...<Widget>[
                    if (_loading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: _liveCyan,
                        backgroundColor: _livePanel,
                      ),
                    for (final fixture in fixtures) _fixtureCard(fixture),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Las señales no vienen incorporadas ni se extraen de páginas de terceros. Añade una URL directa autorizada para asociarla al horario del evento. La reproducción simultánea depende también de la capacidad de decodificación del teléfono y del ancho de banda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _liveMuted,
                      fontSize: 9,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 15),
      child: Column(
        children: <Widget>[
          Icon(icon, color: _liveMuted, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _liveCyan,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _liveMuted,
              height: 1.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class LivePlayerSource {
  const LivePlayerSource({
    required this.title,
    required this.url,
    this.subtitle,
  });

  final String title;
  final String url;
  final String? subtitle;
}

/// Cuatro espacios fijos para ver eventos simultáneos sin desplazarse.
class LivePlayerBoard extends StatelessWidget {
  const LivePlayerBoard({
    super.key,
    required this.sources,
    this.isActive = true,
  });

  final List<LivePlayerSource> sources;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > constraints.maxHeight ? 4 : 2;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final channelNumber = index + 1;
                if (index >= sources.length) {
                  return _WaitingLivePlayerTile(channelNumber: channelNumber);
                }
                final source = sources[index];
                return Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _livePanel,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _liveLine),
                  ),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _LiveVideoTile(
                              key: ValueKey<String>(
                                'board-$channelNumber-${source.url}',
                              ),
                              source: source,
                              initiallyMuted: index > 0,
                              autoStart: false,
                              isActive: isActive,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 29,
                        child: Text(
                          source.subtitle ?? 'Transmisión detectada',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _liveMuted,
                            fontSize: 9,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WaitingLivePlayerTile extends StatelessWidget {
  const _WaitingLivePlayerTile({required this.channelNumber});

  final int channelNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050A13),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _liveLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            color: _livePanel,
            child: Text(
              'DEPORTE TOTAL 360° CANAL $channelNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _liveCyan,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: _liveMuted,
                size: 42,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 7, left: 4, right: 4),
            child: Text(
              'ESPERANDO TRANSMISIÓN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _liveMuted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un reproductor de 1 a 4 cuadros. Cada cuadro administra su propio player nativo.
class LivePlayerGridScreen extends StatefulWidget {
  const LivePlayerGridScreen({
    super.key,
    required this.sources,
    this.refreshSources,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final List<LivePlayerSource> sources;
  final Future<List<LivePlayerSource>> Function()? refreshSources;
  final Duration refreshInterval;

  @override
  State<LivePlayerGridScreen> createState() => _LivePlayerGridScreenState();
}

class _LivePlayerGridScreenState extends State<LivePlayerGridScreen> {
  late List<LivePlayerSource> _sources;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _sources = List<LivePlayerSource>.of(widget.sources);
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant LivePlayerGridScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSources != widget.refreshSources ||
        oldWidget.refreshInterval != widget.refreshInterval) {
      _refreshTimer?.cancel();
      _startRefreshTimer();
    }
    if (oldWidget.sources != widget.sources) {
      _sources = List<LivePlayerSource>.of(widget.sources);
    }
  }

  void _startRefreshTimer() {
    if (widget.refreshSources == null) return;
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _refreshSources());
  }

  Future<void> _refreshSources() async {
    final loader = widget.refreshSources;
    if (loader == null || _refreshing || !mounted) return;
    _refreshing = true;
    try {
      final updated = await loader();
      if (!mounted) return;
      final next = updated
          .where((source) => isSupportedAuthorizedMediaUrl(source.url))
          .take(4)
          .toList(growable: false);
      setState(() => _sources = next);
    } catch (_) {
      // Se mantienen los cuadros actuales si falla una actualización puntual.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeSources = _sources
        .where((source) => isSupportedAuthorizedMediaUrl(source.url))
        .take(4)
        .toList(growable: false);
    final columns = safeSources.length <= 1 ? 1 : 2;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: Text(
          safeSources.length == 1
              ? 'REPRODUCTOR EN VIVO'
              : 'MULTIVISTA · ${safeSources.length}/4 EVENTOS',
          style: const TextStyle(
            color: _liveCyan,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (widget.refreshSources != null)
            IconButton(
              tooltip: 'Actualizar eventos del reproductor',
              onPressed: _refreshing ? null : _refreshSources,
              icon: const Icon(Icons.sync_rounded, color: _liveCyan),
            ),
        ],
      ),
      body: safeSources.isEmpty
          ? const Center(
              child: Text(
                'No hay una fuente multimedia válida.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(7),
              itemCount: safeSources.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: safeSources.length == 1 ? 16 / 9 : 1.32,
              ),
              itemBuilder: (context, index) => _LiveVideoTile(
                key: ValueKey<String>(safeSources[index].url),
                source: safeSources[index],
                initiallyMuted: index > 0,
              ),
            ),
    );
  }
}

class _LiveVideoTile extends StatefulWidget {
  const _LiveVideoTile({
    super.key,
    required this.source,
    required this.initiallyMuted,
    this.autoStart = true,
    this.isActive = true,
  });

  final LivePlayerSource source;
  final bool initiallyMuted;
  final bool autoStart;
  final bool isActive;

  @override
  State<_LiveVideoTile> createState() => _LiveVideoTileState();
}

class _LiveVideoTileState extends State<_LiveVideoTile> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = false;
  bool _showControls = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _muted = widget.initiallyMuted;
    if (widget.autoStart) _initialize();
  }

  @override
  void didUpdateWidget(covariant _LiveVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      final controller = _controller;
      if (controller?.value.isPlaying == true) {
        unawaited(controller!.pause());
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!widget.isActive) return;
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final uri = Uri.tryParse(widget.source.url.trim());
    if (uri == null || !isSupportedAuthorizedMediaUrl(uri.toString())) {
      setState(() {
        _loading = false;
        _error = 'La URL no es un archivo HLS o MP4 directo válido.';
      });
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || !widget.isActive) {
        await controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) {
        await controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }
      setState(() {
        _loading = false;
        _error = 'No se pudo iniciar esta señal: $error';
      });
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  Future<void> _togglePlayback() async {
    if (!widget.isActive) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      await _initialize();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!widget.isActive) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _openFullscreen() async {
    if (!widget.isActive) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final resumeAfter = controller.value.isPlaying;
    await controller.pause();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _LiveFullscreenPlayer(
          title: widget.source.title,
          url: widget.source.url,
        ),
      ),
    );
    if (resumeAfter && mounted && controller.value.isInitialized) {
      await controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050A13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _liveLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (initialized)
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(
                  Icons.live_tv_rounded,
                  size: 34,
                  color: _liveMuted,
                ),
              ),
            ),
          if (!_loading &&
              _error == null &&
              (!initialized || controller?.value.isPlaying == false))
            Center(
              child: IconButton.filled(
                onPressed: _togglePlayback,
                iconSize: 39,
                icon: const Icon(Icons.play_arrow_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: _liveCyan,
                  foregroundColor: Colors.black,
                ),
                tooltip: 'Reproducir transmisión',
              ),
            ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _liveCyan),
            ),
          if (_error != null)
            ColoredBox(
              color: const Color(0xDD000000),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded,
                          color: _liveRed, size: 28),
                      const SizedBox(height: 7),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _initialize,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('REINTENTAR'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (initialized && controller!.value.isBuffering)
            const Positioned(
              top: 42,
              right: 8,
              child: SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _liveCyan,
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.black.withAlpha(150),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.circle, color: _liveRed, size: 7),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (initialized && _showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withAlpha(165),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _togglePlayback,
                      icon: Icon(
                        controller!.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Pausar o reproducir',
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleMute,
                      icon: Icon(
                        _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: _muted ? 'Activar sonido' : 'Silenciar',
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _openFullscreen,
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Pantalla completa',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveFullscreenPlayer extends StatefulWidget {
  const _LiveFullscreenPlayer({
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<_LiveFullscreenPlayer> createState() => _LiveFullscreenPlayerState();
}

class _LiveFullscreenPlayerState extends State<_LiveFullscreenPlayer> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;
  bool _muted = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _initialize() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !isSupportedAuthorizedMediaUrl(uri.toString())) {
      setState(() {
        _loading = false;
        _error = 'La URL multimedia no es válida.';
      });
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo abrir la señal: $error';
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
              if (initialized)
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio > 0
                          ? controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: _liveCyan),
                ),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded,
                            color: _liveRed, size: 36),
                        const SizedBox(height: 9),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: _initialize,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('REINTENTAR'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (initialized && controller!.value.isBuffering)
                const Center(
                  child: CircularProgressIndicator(color: _liveCyan),
                ),
              if (_showControls)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (initialized && _showControls)
                Positioned(
                  bottom: 15,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton.filledTonal(
                        onPressed: _togglePlayback,
                        icon: Icon(
                          controller!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
