import 'package:flutter/material.dart';

import 'app_section_design.dart';
import 'automatic_live_service.dart';
import 'sportsapi_app_service.dart';

const Color _apiStatsBg = Color(0xFF000000);
const Color _apiStatsPanel = Color(0xFF07090D);
const Color _apiStatsLine = Color(0xFF0047FF);
const Color _apiStatsCyan = Color(0xFF00A3FF);
const Color _apiStatsPink = Color(0xFFFF1744);
const Color _apiStatsMuted = Color(0xFFEAF0F8);

class _FavouriteSport {
  const _FavouriteSport(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

class SportsApiStatisticsScreen extends StatefulWidget {
  const SportsApiStatisticsScreen({
    super.key,
    this.initialSport = 'Fútbol',
    this.onOpenAgenda,
  });

  final String initialSport;
  final VoidCallback? onOpenAgenda;

  @override
  State<SportsApiStatisticsScreen> createState() => _SportsApiStatisticsScreenState();
}

class _SportsApiStatisticsScreenState extends State<SportsApiStatisticsScreen> {
  static const List<_FavouriteSport> _sports = <_FavouriteSport>[
    _FavouriteSport('football', 'Fútbol', Icons.sports_soccer_rounded),
    _FavouriteSport('basketball', 'Baloncesto', Icons.sports_basketball_rounded),
    _FavouriteSport('baseball', 'Béisbol', Icons.sports_baseball_rounded),
    _FavouriteSport('ice-hockey', 'Hockey sobre hielo', Icons.sports_hockey_rounded),
    _FavouriteSport('volleyball', 'Voleibol', Icons.sports_volleyball_rounded),
    _FavouriteSport('mma', 'MMA', Icons.sports_mma_rounded),
    _FavouriteSport('futsal', 'Fútbol sala', Icons.sports_soccer_rounded),
    _FavouriteSport('cycling', 'Ciclismo', Icons.directions_bike_rounded),
    _FavouriteSport('motorsport', 'Deportes de motor', Icons.sports_motorsports_rounded),
    _FavouriteSport('handball', 'Balonmano', Icons.sports_handball_rounded),
  ];

  final SportsApiAppService _api = SportsApiAppService();
  String _sportId = 'football';
  List<Map<String, dynamic>> _catalog = <Map<String, dynamic>>[];
  List<SportsAgendaEvent> _events = <SportsAgendaEvent>[];
  SportsAgendaEvent? _selectedEvent;
  List<MapEntry<String, String>> _statistics = <MapEntry<String, String>>[];
  bool _loading = false;
  bool _loadingStats = false;
  String? _error;
  String? _statsError;
  bool _catalogExpanded = false;

  _FavouriteSport get _sport =>
      _sports.firstWhere((item) => item.id == _sportId, orElse: () => _sports.first);

  Map<String, dynamic>? get _currentCatalog {
    for (final row in _catalog) {
      if (row['id']?.toString() == _sportId) return row;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final match = _sports.where((item) =>
      item.id == widget.initialSport || item.name.toLowerCase() == widget.initialSport.toLowerCase());
    if (match.isNotEmpty) _sportId = match.first.id;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.fetchFavoriteSports(),
        _api.fetchFavoriteAgendaEvents(),
      ]);
      final catalog = results[0] as List<Map<String, dynamic>>;
      final events = results[1] as List<SportsAgendaEvent>;
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _events = events;
        _loading = false;
        if (events.isEmpty) {
          _error = 'SportsAPI no devolvió eventos para hoy. Comprueba la conexión, la fecha UTC y la cobertura de tus competiciones favoritas.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedEvent = null;
      _statistics = <MapEntry<String, String>>[];
      _statsError = null;
    });
    try {
      final events = await _api.fetchFavoriteAgendaEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<SportsAgendaEvent> get _visibleEvents {
    final expected = _sport.name.toLowerCase();
    return _events.where((event) =>
      event.sport.toLowerCase() == expected ||
      event.sport.toLowerCase() == _sport.id
    ).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<MapEntry<String, String>> _flatten(dynamic value, [String prefix = '']) {
    final output = <MapEntry<String, String>>[];
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (key == 'id' || key == 'image' || key == 'logo' || key == 'url') {
          continue;
        }
        output.addAll(
          _flatten(entry.value, prefix.isEmpty ? key : '$prefix · $key'),
        );
      }
    } else if (value is List) {
      for (var index = 0; index < value.length; index++) {
        output.addAll(_flatten(value[index], '$prefix ${index + 1}'));
      }
    } else if (value != null && value.toString().trim().isNotEmpty) {
      output.add(MapEntry<String, String>(
        prefix.isEmpty ? 'Dato' : prefix,
        value.toString(),
      ));
    }
    return output;
  }

  List<MapEntry<String, String>> _formatStatistics(dynamic value) {
    if (value is Map && value['periods'] is List) {
      final output = <MapEntry<String, String>>[];
      for (final periodValue in value['periods'] as List) {
        if (periodValue is! Map) continue;
        final period = Map<String, dynamic>.from(periodValue);
        final periodName = (period['name'] ?? period['period'] ?? 'Partido').toString();
        final groups = period['groups'];
        if (groups is! List) continue;
        for (final groupValue in groups) {
          if (groupValue is! Map) continue;
          final group = Map<String, dynamic>.from(groupValue);
          final groupName = (group['name'] ?? group['key'] ?? 'Estadísticas').toString();
          final items = group['items'];
          if (items is! List) continue;
          for (final itemValue in items) {
            if (itemValue is! Map) continue;
            final item = Map<String, dynamic>.from(itemValue);
            final name = (item['name'] ?? item['key'] ?? 'Dato').toString();
            final home = item['home'];
            final away = item['away'];
            String display(dynamic side) {
              if (side is Map) {
                return (side['display'] ?? side['value'] ?? '').toString();
              }
              return (side ?? '').toString();
            }
            final homeText = display(home);
            final awayText = display(away);
            final valueText = <String>[
              if (homeText.isNotEmpty) 'Local: $homeText',
              if (awayText.isNotEmpty) 'Visitante: $awayText',
            ].join('  ·  ');
            if (valueText.isNotEmpty) {
              output.add(MapEntry<String, String>(
                '$periodName · $groupName · $name',
                valueText,
              ));
            }
          }
        }
      }
      if (output.isNotEmpty) return output;
    }
    return _flatten(value);
  }

  Future<void> _loadStatistics(SportsAgendaEvent event) async {
    setState(() {
      _selectedEvent = event;
      _loadingStats = true;
      _statsError = null;
      _statistics = <MapEntry<String, String>>[];
    });
    try {
      dynamic response;
      final fixture = RegExp(r'^sportsapi-fixture-(\d+)$').firstMatch(event.id);
      final race = RegExp(r'^sportsapi-race-(\d+)-(\d+)$').firstMatch(event.id);
      if (fixture != null) {
        response = await _api.fetchFixtureStatistics(int.parse(fixture.group(1)!));
      } else if (race != null) {
        response = await _api.fetchRaceResults(
          int.parse(race.group(1)!),
          sessionId: int.parse(race.group(2)!),
        );
      } else {
        throw const FormatException('Este evento todavía no tiene estadísticas enlazadas a SportsAPI.');
      }
      final rows = _formatStatistics(response);
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
        _statistics = rows.take(48).toList(growable: false);
        if (_statistics.isEmpty) {
          _statsError = 'SportsAPI todavía no ha publicado estadísticas para este evento.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
        _statsError = error.toString();
      });
    }
  }

  Future<void> _loadStandings(SportsAgendaEvent event) async {
    setState(() {
      _selectedEvent = event;
      _loadingStats = true;
      _statsError = null;
      _statistics = <MapEntry<String, String>>[];
    });
    try {
      dynamic response;
      if (event.providerLeagueId != null && event.providerSeasonId != null) {
        response = await _api.fetchLeagueStandings(
          leagueId: event.providerLeagueId!,
          seasonId: event.providerSeasonId!,
        );
      } else if (event.providerSeriesId != null && event.providerSeasonId != null) {
        response = await _api.fetchSeriesStandings(
          seriesId: event.providerSeriesId!,
          seasonId: event.providerSeasonId!,
        );
      } else {
        throw const FormatException(
          'SportsAPI todavía no ha proporcionado la liga, serie o temporada de este evento.',
        );
      }
      final rows = _flatten(response);
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
        _statistics = rows.take(60).toList(growable: false);
        if (_statistics.isEmpty) {
          _statsError = 'SportsAPI todavía no ha publicado una clasificación para esta competición.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
        _statsError = error.toString();
      });
    }
  }


  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final competitions = _currentCatalog?['competitions'];
    final competitionNames = competitions is List
        ? competitions.map((value) => value.toString()).toList(growable: false)
        : <String>[];
    final events = _visibleEvents;

    return Scaffold(
      backgroundColor: _apiStatsBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const AppSectionTitle(
          icon: Icons.analytics_rounded,
          title: 'ESTADÍSTICAS SPORTSAPI',
          accent: _apiStatsCyan,
          subtitle: 'RESULTADOS Y DETALLES POR DEPORTE',
        ),
        actions: <Widget>[
          if (widget.onOpenAgenda != null)
            IconButton(
              tooltip: 'Abrir agenda',
              onPressed: widget.onOpenAgenda,
              icon: const Icon(Icons.calendar_month_rounded, color: _apiStatsCyan),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _apiStatsCyan),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _apiStatsPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _apiStatsLine),
            ),
            child: const Text(
              'Tus 10 deportes favoritos. Selecciona un deporte y abre un partido, combate o carrera para consultar los datos que SportsAPI tenga publicados.',
              style: TextStyle(color: _apiStatsMuted, fontSize: 11, height: 1.45),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _sports.map((sport) => ChoiceChip(
              selected: _sportId == sport.id,
              onSelected: (_) => setState(() {
                _sportId = sport.id;
                _selectedEvent = null;
                _statistics = <MapEntry<String, String>>[];
                _statsError = null;
              }),
              avatar: Icon(sport.icon, size: 15,
                  color: _sportId == sport.id ? _apiStatsBg : _apiStatsCyan),
              label: Text(sport.name),
              selectedColor: _apiStatsCyan,
              backgroundColor: _apiStatsPanel,
              labelStyle: TextStyle(
                color: _sportId == sport.id ? _apiStatsBg : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(color: _sportId == sport.id ? _apiStatsCyan : _apiStatsLine),
            )).toList(growable: false),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _apiStatsPanel,
              border: Border.all(color: _apiStatsLine),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              initiallyExpanded: _catalogExpanded,
              onExpansionChanged: (value) => setState(() => _catalogExpanded = value),
              iconColor: _apiStatsCyan,
              collapsedIconColor: _apiStatsMuted,
              title: const Text('COMPETICIONES FAVORITAS',
                  style: TextStyle(color: _apiStatsCyan, fontSize: 10, fontWeight: FontWeight.w900)),
              subtitle: Text('${competitionNames.length} competiciones configuradas para ${_sport.name}',
                  style: const TextStyle(color: _apiStatsMuted, fontSize: 9)),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: competitionNames.map((name) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1118),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _apiStatsLine),
                        ),
                        child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 9)),
                      )).toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('EVENTOS DE HOY',
                    style: TextStyle(color: _apiStatsCyan, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              Text('${events.length} eventos',
                  style: const TextStyle(color: _apiStatsMuted, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 7),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(child: CircularProgressIndicator(color: _apiStatsCyan)),
            )
          else if (_error != null)
            _message(_error!)
          else if (events.isEmpty)
            _message('No hay eventos publicados hoy para ${_sport.name}. La agenda se actualiza automáticamente desde el Worker.')
          else
            ...events.map((event) => _eventCard(event)),
          if (_selectedEvent != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _apiStatsPanel,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _apiStatsPink.withAlpha(150)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('ESTADÍSTICAS · ${_selectedEvent!.competition}',
                      style: const TextStyle(color: _apiStatsPink, fontSize: 10, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(_selectedEvent!.title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if ((_selectedEvent!.providerLeagueId != null &&
                          _selectedEvent!.providerSeasonId != null) ||
                      (_selectedEvent!.providerSeriesId != null &&
                          _selectedEvent!.providerSeasonId != null))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _loadingStats
                            ? null
                            : () => _loadStandings(_selectedEvent!),
                        icon: const Icon(Icons.leaderboard_rounded, size: 15),
                        label: const Text('VER CLASIFICACIÓN DE LA COMPETICIÓN'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _apiStatsCyan,
                          side: const BorderSide(color: _apiStatsLine),
                          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_loadingStats)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(color: _apiStatsPink),
                    ))
                  else if (_statsError != null)
                    Text(_statsError!, style: const TextStyle(color: _apiStatsMuted, fontSize: 11, height: 1.4))
                  else
                    ..._statistics.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: Text(item.key,
                              style: const TextStyle(color: _apiStatsMuted, fontSize: 10))),
                          const SizedBox(width: 12),
                          Flexible(child: Text(item.value,
                              textAlign: TextAlign.end,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _eventCard(SportsAgendaEvent event) {
    final status = event.status.toLowerCase();
    final isLive = status == 'live' || status == 'inprogress';
    final score = event.homeScore.isNotEmpty || event.awayScore.isNotEmpty
        ? '${event.homeScore.isEmpty ? '-' : event.homeScore} : ${event.awayScore.isEmpty ? '-' : event.awayScore}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: _apiStatsPanel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _loadingStats ? null : () => _loadStatistics(event),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isLive ? _apiStatsPink : _apiStatsLine),
            ),
            child: Row(
              children: <Widget>[
                Icon(_sport.icon, color: isLive ? _apiStatsPink : _apiStatsCyan, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(event.competition, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _apiStatsMuted, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(score.isNotEmpty ? score : _time(event.startsAt),
                        style: TextStyle(color: isLive ? _apiStatsPink : _apiStatsCyan,
                            fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    const Text('VER DATOS', style: TextStyle(color: _apiStatsMuted, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _apiStatsPanel,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _apiStatsLine),
    ),
    child: Text(value, textAlign: TextAlign.center,
        style: const TextStyle(color: _apiStatsMuted, fontSize: 11, height: 1.45)),
  );
}
