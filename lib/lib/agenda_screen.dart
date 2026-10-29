import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const Color agendaBg = Color(0xFF030814);
const Color agendaPanel = Color(0xFF071326);
const Color agendaLine = Color(0xFF123D65);
const Color agendaCyan = Color(0xFF00E5FF);
const Color agendaBlue = Color(0xFF087BFF);
const Color agendaPink = Color(0xFFFF28CF);
const Color agendaGreen = Color(0xFF39FF9C);
const Color agendaRed = Color(0xFFFF3155);
const Color agendaMuted = Color(0xFFA9BDD6);

enum MatchStatus { live, scheduled, finished }

class MatchStreamSource {
  const MatchStreamSource({required this.name, required this.url});

  final String name;
  final String url;

  Uri? get validatedUri {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }
}

class MatchEvent {
  const MatchEvent({
    required this.id,
    required this.sport,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.startsAt,
    this.status = MatchStatus.scheduled,
    this.homeScore,
    this.awayScore,
    this.streamSources = const <MatchStreamSource>[],
    this.sourceName = '',
  });

  final String id;
  final String sport;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final DateTime startsAt;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final List<MatchStreamSource> streamSources;
  final String sourceName;

  bool get hasValidStream =>
      streamSources.any((source) => source.validatedUri != null);
}

/// Agenda nativa para la sección Fútbol y los mosaicos deportivos.
/// El calendario queda vacío hasta conectar una fuente real/autorizada.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({
    super.key,
    this.initialSport = 'Todos',
    this.matches = const <MatchEvent>[],
  });

  final String initialSport;
  final List<MatchEvent> matches;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const List<String> _sports = <String>[
    'Todos',
    'Fútbol',
    'Básquet',
    'Béisbol',
    'Tenis',
    'Vóley',
    'Otros',
  ];

  static const List<String> _statuses = <String>[
    'Todos',
    'En vivo',
    'Programados',
    'Finalizados',
  ];

  late String _sport;
  String _dateFilter = 'Hoy';
  String _statusFilter = 'Todos';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sport = _sports.contains(widget.initialSport)
        ? widget.initialSport
        : 'Todos';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MatchEvent> get _filteredMatches {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final query = _query.trim().toLowerCase();

    return widget.matches.where((event) {
      if (_sport != 'Todos' && event.sport != _sport) return false;
      if (_statusFilter == 'En vivo' &&
          event.status != MatchStatus.live) {
        return false;
      }
      if (_statusFilter == 'Programados' &&
          event.status != MatchStatus.scheduled) {
        return false;
      }
      if (_statusFilter == 'Finalizados' &&
          event.status != MatchStatus.finished) {
        return false;
      }

      final eventDay = DateTime(
        event.startsAt.year,
        event.startsAt.month,
        event.startsAt.day,
      );
      if (_dateFilter == 'Hoy' && eventDay != today) return false;
      if (_dateFilter == 'Mañana' && eventDay != tomorrow) return false;

      if (query.isNotEmpty) {
        final searchable =
            '${event.homeTeam} ${event.awayTeam} ${event.competition} '
                    '${event.sport}'
                .toLowerCase();
        if (!searchable.contains(query)) return false;
      }
      return true;
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _sport = 'Todos';
      _statusFilter = 'Todos';
      _dateFilter = 'Todos';
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredMatches;

    return Scaffold(
      backgroundColor: agendaBg,
      appBar: AppBar(
        backgroundColor: agendaBg,
        title: const Row(
          children: <Widget>[
            Icon(
              Icons.calendar_month_rounded,
              color: agendaCyan,
              size: 24,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'AGENDA DE PARTIDOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Limpiar búsqueda',
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded, color: agendaCyan),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: <Color>[
              Color(0xFF101B42),
              agendaBg,
              Color(0xFF08071B),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar equipo, liga o deporte…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: agendaCyan,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: agendaPanel,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: agendaLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: agendaCyan,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    for (final date in <String>[
                      'Hoy',
                      'Mañana',
                      'Todos',
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _FilterButton(
                            label: date,
                            selected: _dateFilter == date,
                            onTap: () => setState(() => _dateFilter = date),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _sports.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final value = _sports[index];
                    return ChoiceChip(
                      label: Text(value),
                      selected: _sport == value,
                      onSelected: (_) => setState(() => _sport = value),
                      selectedColor: agendaBlue,
                      backgroundColor: agendaPanel,
                      labelStyle: TextStyle(
                        color:
                            _sport == value ? Colors.white : agendaMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: _sport == value ? agendaCyan : agendaLine,
                      ),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 35,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final value = _statuses[index];
                    final selected = _statusFilter == value;
                    final color =
                        value == 'En vivo' ? agendaRed : agendaGreen;
                    return InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => _statusFilter = value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected ? color.withAlpha(35) : agendaPanel,
                          border: Border.all(
                            color: selected ? color : agendaLine,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            color: selected ? color : agendaMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'PARTIDOS Y EVENTOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                    Text(
                      '${events.length} eventos',
                      style: const TextStyle(
                        color: agendaMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? _EmptyAgenda(
                        hasSearch: _query.trim().isNotEmpty,
                        onClear: _clearFilters,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: events.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _MatchCard(
                          event: events[index],
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MatchDetailScreen(event: events[index]),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? agendaBlue : agendaPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? agendaCyan : agendaLine,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : agendaMuted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({
    required this.hasSearch,
    required this.onClear,
  });

  final bool hasSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
            decoration: BoxDecoration(
              color: agendaPanel.withAlpha(235),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: agendaLine),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: agendaCyan.withAlpha(18),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: agendaBlue.withAlpha(30),
                    border: Border.all(color: agendaCyan.withAlpha(120)),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: agendaCyan,
                    size: 39,
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  hasSearch
                      ? 'No hay resultados'
                      : 'Agenda lista para conectarse',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  hasSearch
                      ? 'Prueba con otro equipo, competición o deporte.'
                      : 'Esta pantalla ya es nativa de Deporte Total 360°. '
                          'Todavía no hay una fuente de partidos reales '
                          'conectada, así que no mostramos horarios inventados '
                          'ni botones de reproducción sin destino.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: agendaMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Limpiar filtros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: agendaCyan,
                    side: const BorderSide(color: agendaCyan),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.event, required this.onTap});

  final MatchEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = event.status == MatchStatus.live
        ? agendaRed
        : event.status == MatchStatus.finished
            ? agendaMuted
            : agendaGreen;
    final statusText = event.status == MatchStatus.live
        ? 'EN VIVO'
        : event.status == MatchStatus.finished
            ? 'FINALIZADO'
            : 'PROGRAMADO';
    final sourceReady = event.hasValidStream;

    return Material(
      color: agendaPanel.withAlpha(245),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: agendaLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    _sportIcon(event.sport),
                    color: agendaCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.competition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: agendaCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(28),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TeamName(
                      name: event.homeTeam,
                      score: event.homeScore,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: agendaMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TeamName(
                      name: event.awayTeam,
                      score: event.awayScore,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _dateLabel(event.startsAt),
                      style: const TextStyle(
                        color: agendaMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (sourceReady)
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: agendaGreen,
                      size: 16,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    sourceReady ? 'Ver opciones' : 'Detalles',
                    style: TextStyle(
                      color: sourceReady ? agendaGreen : agendaCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: agendaMuted,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName({
    required this.name,
    this.score,
    this.alignEnd = false,
  });

  final String name;
  final int? score;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final alignment = alignEnd ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignment,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (score != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            '$score',
            textAlign: alignment,
            style: const TextStyle(
              color: agendaCyan,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({super.key, required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final sources = event.streamSources
        .where((source) => source.validatedUri != null)
        .toList();

    return Scaffold(
      backgroundColor: agendaBg,
      appBar: AppBar(
        backgroundColor: agendaBg,
        title: const Text(
          'DETALLES DEL EVENTO',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: <Color>[
              Color(0xFF101B42),
              agendaBg,
              Color(0xFF08071B),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: agendaPanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: agendaCyan.withAlpha(160)),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    event.competition.toUpperCase(),
                    style: const TextStyle(
                      color: agendaCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          event.homeTeam,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          event.homeScore == null || event.awayScore == null
                              ? 'VS'
                              : '${event.homeScore} : ${event.awayScore}',
                          style: const TextStyle(
                            color: agendaPink,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          event.awayTeam,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '${event.sport} • ${_dateLabel(event.startsAt)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: agendaMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'OPCIONES DE REPRODUCCIÓN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 9),
            if (sources.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: agendaPanel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: agendaLine),
                ),
                child: const Column(
                  children: <Widget>[
                    Icon(
                      Icons.videocam_off_rounded,
                      color: agendaMuted,
                      size: 42,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No hay una fuente de vídeo configurada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'El reproductor se habilitará cuando se conecte una '
                      'fuente válida y autorizada para este evento. No se '
                      'inventan enlaces ni se eluden protecciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: agendaMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: agendaBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => AgendaVideoPlayerScreen(
                            title: '${event.homeTeam} vs ${event.awayTeam}',
                            source: source,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: Text('Reproducir • ${source.name}'),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'La app reproduce únicamente URLs HTTP/HTTPS suministradas '
              'por una fuente válida. La compatibilidad del stream depende '
              'de su formato, disponibilidad y permisos.',
              style: TextStyle(color: agendaMuted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AgendaVideoPlayerScreen extends StatefulWidget {
  const AgendaVideoPlayerScreen({
    super.key,
    required this.title,
    required this.source,
  });

  final String title;
  final MatchStreamSource source;

  @override
  State<AgendaVideoPlayerScreen> createState() =>
      _AgendaVideoPlayerScreenState();
}

class _AgendaVideoPlayerScreenState extends State<AgendaVideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final uri = widget.source.validatedUri;
    if (uri == null) {
      setState(() {
        _loading = false;
        _error = 'La dirección de vídeo no es una URL HTTP/HTTPS válida.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar el vídeo. Comprueba la fuente, la conexión y los permisos de acceso.';
      });
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _durationLabel(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: agendaBg,
      appBar: AppBar(
        backgroundColor: agendaBg,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: agendaCyan),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: controller?.value.isInitialized == true
                  ? controller!.value.aspectRatio
                  : 16 / 9,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: agendaCyan),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: agendaRed,
                                  size: 38,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _initialize,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: agendaCyan,
                                    side: const BorderSide(color: agendaCyan),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : controller == null || !controller.value.isInitialized
                          ? const Center(
                              child: Text(
                                'El reproductor no está disponible.',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : GestureDetector(
                              onTap: () async {
                                if (controller.value.isPlaying) {
                                  await controller.pause();
                                } else {
                                  await controller.play();
                                }
                                if (mounted) setState(() {});
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  VideoPlayer(controller),
                                  if (!controller.value.isPlaying)
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: agendaBlue.withAlpha(210),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                ],
                              ),
                            ),
            ),
          ),
          if (!_loading &&
              _error == null &&
              controller != null &&
              controller.value.isInitialized) ...<Widget>[
            const SizedBox(height: 12),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => Column(
                children: <Widget>[
                  Slider(
                    value: value.duration.inMilliseconds <= 0
                        ? 0
                        : value.position.inMilliseconds
                            .clamp(0, value.duration.inMilliseconds)
                            .toDouble(),
                    max: value.duration.inMilliseconds <= 0
                        ? 1
                        : value.duration.inMilliseconds.toDouble(),
                    activeColor: agendaCyan,
                    inactiveColor: agendaLine,
                    onChanged: value.duration.inMilliseconds <= 0
                        ? null
                        : (position) => controller.seekTo(
                              Duration(milliseconds: position.round()),
                            ),
                  ),
                  Row(
                    children: <Widget>[
                      Text(
                        _durationLabel(value.position),
                        style: const TextStyle(
                          color: agendaMuted,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _durationLabel(value.duration),
                        style: const TextStyle(
                          color: agendaMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      if (value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) setState(() {});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: agendaBlue,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(value.isPlaying ? 'Pausar' : 'Reproducir'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Fuente seleccionada: ${widget.source.name}',
            style: const TextStyle(
              color: agendaCyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Si aparece un error, la fuente puede estar fuera de línea, '
            'requerir permisos o utilizar un formato no compatible. La app '
            'no intenta eludir autenticación ni DRM.',
            style: TextStyle(color: agendaMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

IconData _sportIcon(String sport) {
  switch (sport) {
    case 'Fútbol':
      return Icons.sports_soccer_rounded;
    case 'Básquet':
      return Icons.sports_basketball_rounded;
    case 'Béisbol':
      return Icons.sports_baseball_rounded;
    case 'Tenis':
      return Icons.sports_tennis_rounded;
    case 'Vóley':
      return Icons.sports_volleyball_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month • $hour:$minute';
}