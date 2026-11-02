import 'package:flutter/material.dart';
import 'app_i18n.dart';
import 'sports_api_service.dart';

const Color _statsBg = Color(0xFF030814);
const Color _statsPanel = Color(0xFF071326);
const Color _statsLine = Color(0xFF123D65);
const Color _statsCyan = Color(0xFF00E5FF);
const Color _statsBlue = Color(0xFF087BFF);
const Color _statsMuted = Color(0xFFA9BDD6);

class _SportOption {
  const _SportOption(this.id, this.name, this.icon, this.mode);
  final String id;
  final String name;
  final IconData icon;
  final String mode;
}

class SportsStatisticsScreen extends StatefulWidget {
  const SportsStatisticsScreen({super.key, this.initialSport = 'Fútbol', this.onOpenAgenda});
  final String initialSport;
  final VoidCallback? onOpenAgenda;
  @override
  State<SportsStatisticsScreen> createState() => _SportsStatisticsScreenState();
}

class _SportsStatisticsScreenState extends State<SportsStatisticsScreen> {
  static const List<_SportOption> _sports = <_SportOption>[
    _SportOption('football', 'Fútbol', Icons.sports_soccer_rounded, 'table'),
    _SportOption('basketball', 'Básquet', Icons.sports_basketball_rounded, 'table'),
    _SportOption('nba', 'NBA', Icons.sports_basketball_rounded, 'table'),
    _SportOption('baseball', 'Béisbol', Icons.sports_baseball_rounded, 'table'),
    _SportOption('american-football', 'Fútbol americano / NFL', Icons.sports_football_rounded, 'table'),
    _SportOption('hockey', 'Hockey sobre hielo', Icons.sports_hockey_rounded, 'table'),
    _SportOption('handball', 'Balonmano', Icons.sports_handball_rounded, 'table'),
    _SportOption('rugby', 'Rugby', Icons.sports_rugby_rounded, 'table'),
    _SportOption('volleyball', 'Voleibol', Icons.sports_volleyball_rounded, 'table'),
    _SportOption('afl', 'Fútbol australiano', Icons.sports_football_rounded, 'table'),
    _SportOption('formula-1', 'Fórmula 1', Icons.sports_motorsports_rounded, 'formula1'),
    _SportOption('mma', 'MMA', Icons.sports_mma_rounded, 'mma'),
  ];

  final SportsApiService _service = SportsApiService();
  final TextEditingController _searchController = TextEditingController();
  String _sportId = 'football';
  String _season = DateTime.now().year.toString();
  String _formulaRanking = 'driver-rankings';
  String? _selectedLeagueId;
  String _selectedLeagueName = '';
  List<String> _seasons = <String>[];
  List<Map<String, dynamic>> _leagues = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  bool _searching = false;
  bool _loadingRows = false;
  String? _error;
  String _resultHeading = '';

  @override
  void initState() {
    super.initState();
    _sportId = SportsApiService.supportedSports[widget.initialSport] ??
        (_sports.any((item) => item.id == widget.initialSport)
            ? widget.initialSport
            : 'football');
  }

  _SportOption get _sport => _sports.firstWhere(
        (item) => item.id == _sportId,
        orElse: () => _sports.first,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _name(dynamic value) {
    if (value is Map) {
      final map = _map(value);
      return (map['name'] ?? map['title'] ?? map['shortName'] ??
              map['fullname'] ?? '')
          .toString()
          .trim();
    }
    return (value ?? '').toString().trim();
  }

  String _leagueId(Map<String, dynamic> row) {
    final league = _map(row['league']);
    return (league['id'] ?? row['league_id'] ?? row['id'] ?? '').toString();
  }

  String _leagueName(Map<String, dynamic> row) {
    final league = _map(row['league']);
    return _name(league['name'] ?? row['name'] ?? row['competition']);
  }

  String? _imageUrl(dynamic value) {
    if (value is! String) return null;
    final url = value.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return url;
  }

  String? _leagueLogo(Map<String, dynamic> row) {
    final league = _map(row['league']);
    return _imageUrl(league['logo'] ?? row['logo'] ?? row['image']);
  }

  List<String> _leagueSeasons(Map<String, dynamic> row) {
    final values = row['seasons'];
    if (values is! List) return <String>[];
    final seasons = <String>[];
    for (final value in values) {
      final item = _map(value);
      final year = (item['year'] ?? value).toString().trim();
      if (RegExp(r'^\d{4}(?:-\d{4})?$').hasMatch(year) &&
          !seasons.contains(year)) {
        seasons.add(year);
      }
    }
    seasons.sort((a, b) => b.compareTo(a));
    return seasons;
  }

  void _resetResults() {
    _selectedLeagueId = null;
    _selectedLeagueName = '';
    _seasons = <String>[];
    _leagues = <Map<String, dynamic>>[];
    _rows = <Map<String, dynamic>>[];
    _error = null;
    _resultHeading = '';
  }

  void _selectSport(String? value) {
    if (value == null || value == _sportId) return;
    setState(() {
      _sportId = value;
      _resetResults();
      _searchController.clear();
    });
  }

  Future<void> _search() async {
    if (_sport.mode == 'formula1') {
      await _loadFormulaRanking();
      return;
    }
    if (_sport.mode == 'mma') {
      await _searchMmaFighters();
      return;
    }
    final term = _searchController.text.trim();
    if (term.isEmpty) {
      setState(() => _error = appText(
            'Escribe el nombre de una liga o competición.',
            'Enter a league or competition name.',
            'Digite o nome de uma liga ou competição.',
            'Saisissez le nom d’une ligue ou compétition.',
          ));
      return;
    }
    setState(() {
      _searching = true;
      _resetResults();
    });
    try {
      final rows = await _service.fetchLeagues(sport: _sport.name, search: term);
      if (!mounted) return;
      setState(() {
        _leagues = rows;
        _searching = false;
        if (rows.isEmpty) {
          _error = appText('No se encontraron ligas con ese nombre.',
              'No leagues were found for that name.',
              'Nenhuma liga foi encontrada com esse nome.',
              'Aucune ligue trouvée pour ce nom.');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.toString();
      });
    }
  }

  void _selectLeague(Map<String, dynamic> row) {
    final id = _leagueId(row);
    if (id.isEmpty) {
      setState(() => _error = appText(
          'La respuesta no incluye un identificador de liga.',
          'The response does not include a league identifier.',
          'A resposta não inclui um identificador de liga.',
          'La réponse ne contient pas d’identifiant de ligue.'));
      return;
    }
    final seasons = _leagueSeasons(row);
    String? currentSeason;
    final rawSeasons = row['seasons'];
    if (rawSeasons is List) {
      for (final value in rawSeasons) {
        final item = _map(value);
        if (item['current'] == true && item['year'] != null) {
          currentSeason = item['year'].toString();
          break;
        }
      }
    }
    setState(() {
      _selectedLeagueId = id;
      _selectedLeagueName = _leagueName(row);
      _seasons = seasons;
      _season = currentSeason ??
          (seasons.isEmpty ? DateTime.now().year.toString() : seasons.first);
      _rows = <Map<String, dynamic>>[];
      _error = null;
      _resultHeading = '';
    });
  }

  List<Map<String, dynamic>> _extractStandingRows(
      List<Map<String, dynamic>> roots) {
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    void visit(dynamic node) {
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      final team = map['team'] ?? map['competitor'] ?? map['participant'];
      final hasPosition = map.containsKey('rank') ||
          map.containsKey('position') ||
          map.containsKey('place');
      if (hasPosition &&
          (team != null ||
              map.containsKey('points') ||
              map.containsKey('name') ||
              map.containsKey('driver'))) {
        final position = map['rank'] ?? map['position'] ?? map['place'];
        final identity = position.toString() + ':' +
            (_name(team).isEmpty ? _name(map['name']) : _name(team));
        if (seen.add(identity)) rows.add(map);
        return;
      }
      for (final value in map.values) {
        visit(value);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    rows.sort((a, b) {
      final ar = int.tryParse(
              (a['rank'] ?? a['position'] ?? a['place'] ?? 9999).toString()) ??
          9999;
      final br = int.tryParse(
              (b['rank'] ?? b['position'] ?? b['place'] ?? 9999).toString()) ??
          9999;
      return ar.compareTo(br);
    });
    return rows;
  }

  Future<void> _loadStandings() async {
    final id = _selectedLeagueId;
    if (id == null) {
      setState(() => _error = appText('Primero selecciona una liga.',
          'Select a league first.', 'Selecione uma liga primeiro.',
          'Sélectionnez d’abord une ligue.'));
      return;
    }
    setState(() {
      _loadingRows = true;
      _error = null;
      _rows = <Map<String, dynamic>>[];
    });
    try {
      final result = await _service.fetchStandings(
          sport: _sport.name, leagueId: id, season: _season);
      final rows = _extractStandingRows(result);
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _rows = rows;
        _resultHeading = _selectedLeagueName + ' • ' + _season;
        if (rows.isEmpty) {
          _error = appText(
              'La API no devolvió una clasificación para esta liga y temporada.',
              'The API returned no standings for this league and season.',
              'A API não retornou uma classificação para esta liga e temporada.',
              'L’API n’a renvoyé aucun classement pour cette ligue et cette saison.');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadFormulaRanking() async {
    setState(() {
      _loadingRows = true;
      _error = null;
      _rows = <Map<String, dynamic>>[];
    });
    try {
      final rows = await _service.fetchFormula1Rankings(
          season: _season, ranking: _formulaRanking);
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _rows = rows;
        _resultHeading = _formulaRanking == 'driver-rankings'
            ? appText('Clasificación de pilotos', 'Driver standings',
                'Classificação de pilotos', 'Classement des pilotes')
            : appText('Clasificación de constructores', 'Team standings',
                'Classificação de construtores', 'Classement des constructeurs');
        if (rows.isEmpty) {
          _error = appText('No hay datos de clasificación para esa temporada.',
              'No ranking data is available for this season.',
              'Não há dados de classificação para esta temporada.',
              'Aucune donnée de classement pour cette saison.');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadMmaFights() async {
    setState(() {
      _loadingRows = true;
      _error = null;
      _rows = <Map<String, dynamic>>[];
    });
    try {
      final rows = await _service.fetchMmaFights();
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _rows = rows;
        _resultHeading = appText('Combates disponibles', 'Available fights',
            'Lutas disponíveis', 'Combats disponibles');
        if (rows.isEmpty) {
          _error = appText('No hay combates disponibles para la fecha actual.',
              'No fights are available for the current date.',
              'Não há lutas disponíveis para a data atual.',
              'Aucun combat disponible pour la date actuelle.');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _searchMmaFighters() async {
    final term = _searchController.text.trim();
    if (term.isEmpty) {
      await _loadMmaFights();
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _rows = <Map<String, dynamic>>[];
    });
    try {
      final rows = await _service.fetchMmaFighters(search: term);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _rows = rows;
        _resultHeading = appText('Luchadores encontrados', 'Fighters found',
            'Lutadores encontrados', 'Combattants trouvés');
        if (rows.isEmpty) {
          _error = appText('No se encontraron luchadores.',
              'No fighters were found.', 'Nenhum lutador foi encontrado.',
              'Aucun combattant trouvé.');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.toString();
      });
    }
  }

  String _rowName(Map<String, dynamic> row) {
    final candidates = <dynamic>[
      row['team'], row['competitor'], row['participant'], row['driver'],
      row['fighter'], row['fighter1'], row['red'], row['home'],
      row['competitor1'], row['player'], row['name'], row['event'],
      row['fight'], row['circuit'], row['title']
    ];
    for (final candidate in candidates) {
      if (_name(candidate).isNotEmpty) return _name(candidate);
    }
    return '';
  }

  String? _rowLogo(Map<String, dynamic> row) {
    final team = _map(row['team'] ?? row['competitor'] ?? row['participant']);
    final driver = _map(row['driver']);
    final fighter = _map(row['fighter'] ?? row['fighter1'] ?? row['red']);
    final player = _map(row['player']);
    return _imageUrl(team['logo'] ?? team['image'] ?? driver['image'] ??
        driver['photo'] ?? fighter['image'] ?? fighter['photo'] ??
        player['photo'] ?? row['logo'] ?? row['image']);
  }

  String _rowDetails(Map<String, dynamic> row) {
    final all = _map(row['all'] ?? row['games'] ?? row['statistics']);
    final fields = <String>[];
    final id = row['id'] ?? _map(row['team'])['id'] ??
        _map(row['driver'])['id'] ?? _map(row['fighter'])['id'];
    final rank = row['rank'] ?? row['position'] ?? row['place'];
    final played = all['played'] ?? all['games'] ?? row['played'];
    final wins = all['win'] ?? all['wins'] ?? row['wins'];
    final draws = all['draw'] ?? all['draws'];
    final losses = all['lose'] ?? all['losses'] ?? row['losses'];
    final points = row['points'] ?? row['point'] ?? row['score'];
    final country = _name(row['country']);
    final stage = row['stage'] ?? row['round'] ?? row['category'];
    if (id != null) fields.add('ID ' + id.toString());
    if (rank != null) fields.add('#' + rank.toString());
    if (country.isNotEmpty) fields.add(country);
    if (stage != null) fields.add(stage.toString());
    if (played != null) fields.add('PJ ' + played.toString());
    if (wins != null) fields.add('G ' + wins.toString());
    if (draws != null) fields.add('E ' + draws.toString());
    if (losses != null) fields.add('P ' + losses.toString());
    if (points != null) fields.add('PTS ' + points.toString());
    return fields.join('  ·  ');
  }

  Widget _logo(String? url) {
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B31),
        shape: BoxShape.circle,
        border: Border.all(color: _statsLine),
      ),
      child: url == null
          ? const Icon(Icons.shield_rounded, color: _statsCyan, size: 23)
          : ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_rounded, color: _statsCyan, size: 23),
              ),
            ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _statsBlue.withAlpha(30),
          border: Border.all(color: _statsBlue.withAlpha(130)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(
            color: _statsCyan, fontSize: 10, fontWeight: FontWeight.w900)),
      );

  @override
  Widget build(BuildContext context) {
    final isFormula1 = _sport.mode == 'formula1';
    final isMma = _sport.mode == 'mma';
    return Scaffold(
      backgroundColor: _statsBg,
      appBar: AppBar(
        backgroundColor: _statsBg,
        title: Text(tr('stats_title'), style: const TextStyle(
            color: _statsCyan, fontSize: 14, fontWeight: FontWeight.w900)),
        actions: <Widget>[
          if (widget.onOpenAgenda != null)
            IconButton(
              tooltip: tr('matches'),
              onPressed: widget.onOpenAgenda,
              icon: const Icon(Icons.calendar_month_rounded, color: _statsCyan),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: <Widget>[
          Text(tr('stats_description'), style: const TextStyle(
              color: _statsMuted, fontSize: 12, height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: <Widget>[
            _pill('SPORT ID  •  ' + _sport.id),
            _pill('API-Sports'),
            _pill('12 deportes'),
          ]),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            value: _sportId,
            decoration: InputDecoration(
              labelText: appText('Deporte', 'Sport', 'Esporte', 'Sport'),
              filled: true,
              fillColor: _statsPanel,
              prefixIcon: Icon(_sport.icon, color: _statsCyan),
            ),
            dropdownColor: _statsPanel,
            items: _sports.map((sport) => DropdownMenuItem<String>(
                value: sport.id, child: Text(sport.name + '  ·  ' + sport.id)))
                .toList(),
            onChanged: _selectSport,
          ),
          const SizedBox(height: 10),
          if (isFormula1) ...<Widget>[
            DropdownButtonFormField<String>(
              value: _formulaRanking,
              decoration: InputDecoration(
                labelText: appText('Tipo de clasificación', 'Ranking type',
                    'Tipo de classificação', 'Type de classement'),
                filled: true, fillColor: _statsPanel),
              dropdownColor: _statsPanel,
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'driver-rankings',
                    child: Text(appText('Pilotos', 'Drivers', 'Pilotos', 'Pilotes'))),
                DropdownMenuItem(value: 'team-rankings',
                    child: Text(appText('Constructores', 'Teams', 'Equipes', 'Écuries'))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _formulaRanking = value);
              },
            ),
            const SizedBox(height: 10),
          ],
          if (!isFormula1) ...<Widget>[
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: isMma
                    ? appText('Buscar luchador', 'Search fighter',
                        'Buscar lutador', 'Rechercher un combattant')
                    : appText('Buscar liga o competición',
                        'Search league or competition',
                        'Buscar liga ou competição',
                        'Rechercher une ligue ou compétition'),
                hintText: isMma ? 'Ej.: Alex Pereira' : 'Ej.: Premier League',
                filled: true, fillColor: _statsPanel,
                suffixIcon: IconButton(
                  tooltip: appText('Buscar', 'Search', 'Buscar', 'Rechercher'),
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.search_rounded, color: _statsCyan)),
              ),
            ),
            const SizedBox(height: 9),
          ],
          if (!isMma) ...<Widget>[
            DropdownButtonFormField<String>(
              value: _season,
              decoration: InputDecoration(
                labelText: appText('Temporada', 'Season', 'Temporada', 'Saison'),
                filled: true, fillColor: _statsPanel),
              dropdownColor: _statsPanel,
              items: (_seasons.isEmpty ? <String>[_season] : _seasons)
                  .map((season) => DropdownMenuItem<String>(
                      value: season, child: Text(season))).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _season = value);
              },
            ),
            const SizedBox(height: 9),
          ],
          Row(children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _searching || _loadingRows ? null : _search,
                icon: _searching ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.manage_search_rounded),
                label: Text(_searching
                    ? appText('BUSCANDO…', 'SEARCHING…', 'BUSCANDO…', 'RECHERCHE…')
                    : isFormula1
                        ? appText('CARGAR CLASIFICACIÓN', 'LOAD RANKING',
                            'CARREGAR CLASSIFICAÇÃO', 'CHARGER LE CLASSEMENT')
                        : isMma
                            ? appText('BUSCAR LUCHADOR', 'SEARCH FIGHTER',
                                'BUSCAR LUTADOR', 'RECHERCHER UN COMBATTANT')
                            : appText('BUSCAR LIGAS', 'SEARCH LEAGUES',
                                'BUSCAR LIGAS', 'RECHERCHER DES LIGUES')),
                style: OutlinedButton.styleFrom(foregroundColor: _statsCyan,
                    side: const BorderSide(color: _statsCyan)),
              ),
            ),
            if (isMma) ...<Widget>[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loadingRows ? null : _loadMmaFights,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(appText('COMBATES DE HOY', 'TODAY’S FIGHTS',
                      'LUTAS DE HOJE', 'COMBATS DU JOUR')),
                  style: FilledButton.styleFrom(
                      backgroundColor: _statsCyan, foregroundColor: _statsBg),
                ),
              ),
            ],
          ]),
          if (_leagues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 17),
            Text(appText('RESULTADOS DE LIGAS', 'LEAGUE RESULTS',
                'RESULTADOS DE LIGAS', 'RÉSULTATS DES LIGUES'),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            ..._leagues.take(20).map((row) {
              final id = _leagueId(row);
              final selected = id == _selectedLeagueId;
              final country = _name(row['country']);
              final seasons = _leagueSeasons(row);
              return Card(
                color: selected ? const Color(0xFF102746) : _statsPanel,
                shape: RoundedRectangleBorder(
                    side: BorderSide(color: selected ? _statsCyan : _statsLine),
                    borderRadius: BorderRadius.circular(11)),
                child: ListTile(
                  dense: true,
                  leading: _logo(_leagueLogo(row)),
                  title: Text(_leagueName(row).isEmpty ? 'Liga ' + id : _leagueName(row),
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  subtitle: Text('ID ' + id + '  ·  SPORT ' + _sport.id +
                      (country.isEmpty ? '' : '  ·  ' + country) +
                      (seasons.isEmpty ? '' : '  ·  ' + seasons.length.toString() + ' temporadas'),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _statsMuted, fontSize: 9)),
                  trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right,
                      color: _statsCyan),
                  onTap: () => _selectLeague(row),
                ),
              );
            }),
          ],
          if (_selectedLeagueId != null && !isFormula1 && !isMma) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: _statsPanel,
                  border: Border.all(color: _statsCyan.withAlpha(150)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(_selectedLeagueName + '  ·  ID ' + _selectedLeagueId!,
                      style: const TextStyle(color: _statsCyan,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _loadingRows ? null : _loadStandings,
                    icon: _loadingRows ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _statsBg))
                        : const Icon(Icons.leaderboard_rounded),
                    label: Text(appText('VER ESTADÍSTICAS Y TABLA',
                        'VIEW STATISTICS AND STANDINGS',
                        'VER ESTATÍSTICAS E TABELA',
                        'VOIR LES STATISTIQUES ET LE CLASSEMENT')),
                    style: FilledButton.styleFrom(backgroundColor: _statsCyan,
                        foregroundColor: _statsBg),
                  ),
                ]),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF2A1424),
                  border: Border.all(color: const Color(0xFFFF28CF)),
                  borderRadius: BorderRadius.circular(11)),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
          if (_loadingRows) ...<Widget>[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator(color: _statsCyan)),
          ],
          if (_rows.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(_resultHeading.isEmpty ? _sport.name : _resultHeading,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 7),
            ..._rows.take(60).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final rank = row['rank'] ?? row['position'] ?? row['place'] ?? index + 1;
              final points = row['points'] ?? row['point'] ?? row['score'];
              final name = _rowName(row);
              final subtitle = _rowDetails(row);
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(color: _statsPanel,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _statsLine)),
                child: Row(children: <Widget>[
                  SizedBox(width: 27, child: Text(rank.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _statsCyan,
                          fontWeight: FontWeight.w900, fontSize: 15))),
                  const SizedBox(width: 8),
                  _logo(_rowLogo(row)),
                  const SizedBox(width: 9),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name.isEmpty ? appText('Participante', 'Participant',
                          'Participante', 'Participant') : name,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 12)),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(subtitle, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _statsMuted, fontSize: 9)),
                      ],
                    ],
                  )),
                  if (points != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Column(children: <Widget>[
                      Text(points.toString(), style: const TextStyle(
                          color: _statsCyan, fontWeight: FontWeight.w900, fontSize: 17)),
                      const Text('PTS', style: TextStyle(color: _statsMuted, fontSize: 8)),
                    ]),
                  ],
                ]),
              );
            }),
          ],
          const SizedBox(height: 14),
          Text(appText(
            'Los IDs y logos se muestran cuando API-Sports los incluye en su respuesta. La cobertura depende del deporte, la competición, la temporada y tu plan de API.',
            'IDs and logos are displayed when API-Sports includes them. Coverage depends on sport, competition, season and your API plan.',
            'IDs e logos são exibidos quando a API-Sports os inclui. A cobertura depende do esporte, competição, temporada e plano da API.',
            'Les identifiants et logos sont affichés lorsque API-Sports les fournit. La couverture dépend du sport, de la compétition, de la saison et du forfait API.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _statsMuted, fontSize: 10, height: 1.45)),
        ],
      ),
    );
  }
}
