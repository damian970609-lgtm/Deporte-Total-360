import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'sportsapi_app_service.dart';

const Color _agendaBg = Color(0xFF030814);
const Color _agendaPanel = Color(0xFF071326);
const Color _agendaLine = Color(0xFF123D65);
const Color _agendaCyan = Color(0xFF00E5FF);
const Color _agendaGreen = Color(0xFF39FF9C);
const Color _agendaPink = Color(0xFFFF28CF);
const Color _agendaMuted = Color(0xFFA9BDD6);
const Color _agendaRed = Color(0xFFFF3155);

typedef AgendaEventsLoader = Future<List<SportsAgendaEvent>?> Function();

/// Agenda nativa basada exclusivamente en el calendario de SportsAPI.app.
class SportsApiAgendaScreen extends StatefulWidget {
  const SportsApiAgendaScreen({
    super.key,
    required this.onOpenLive,
    this.isActive = true,
    this.loadEvents,
  });

  final VoidCallback onOpenLive;
  final bool isActive;
  @visibleForTesting
  final AgendaEventsLoader? loadEvents;

  @override
  State<SportsApiAgendaScreen> createState() => _SportsApiAgendaScreenState();
}

class _SportsApiAgendaScreenState extends State<SportsApiAgendaScreen>
    with WidgetsBindingObserver {
  List<SportsAgendaEvent> _events = <SportsAgendaEvent>[];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _syncRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant SportsApiAgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncRefreshTimer();
      if (widget.isActive) _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _refresh();
    }
  }

  void _syncRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (widget.isActive) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _refresh(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<SportsAgendaEvent>> _loadEvents() async {
    final injectedLoader = widget.loadEvents;
    if (injectedLoader != null) {
      return await injectedLoader() ?? <SportsAgendaEvent>[];
    }

    // SportsAPI es la fuente principal de los diez deportes favoritos.
    // Los errores se elevan a _refresh para poder mostrar el motivo real.
    final events = await SportsApiAppService().fetchFavoriteAgendaEvents();
    await SportsAgendaStore.save(events);
    return events;
  }

  Future<void> _refresh() async {
    if (_loading && _hasLoaded) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final loaded = await _loadEvents();
      final now = DateTime.now();
      // La pestaña Agenda de hoy presenta los eventos cuya fecha local de
      // inicio coincide con la fecha del teléfono; el almacén conserva todos
      // los eventos recibidos para que el planificador encuentre los próximos.
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final visibleById = <String, SportsAgendaEvent>{};
      for (final event in loaded) {
        final localStart = event.startsAt.toLocal();
        if (localStart.isBefore(today) || !localStart.isBefore(tomorrow)) {
          continue;
        }
        visibleById.putIfAbsent(event.id, () => event);
      }
      final visible = visibleById.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      if (!mounted) return;
      setState(() {
        _events = visible;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (error) {
      final saved = await SportsAgendaStore.load();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final visibleById = <String, SportsAgendaEvent>{};
      for (final event in saved) {
        final localStart = event.startsAt.toLocal();
        if (localStart.isBefore(today) || !localStart.isBefore(tomorrow)) {
          continue;
        }
        visibleById.putIfAbsent(event.id, () => event);
      }
      final visible = visibleById.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (!mounted) return;
      setState(() {
        _events = visible;
        _loading = false;
        _hasLoaded = true;
        _error = error.toString();
      });
    }
  }

  String _dayLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'HOY';
    if (day == today.add(const Duration(days: 1))) return 'MAÑANA';
    const weekdays = <String>[
      'LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'
    ];
    const months = <String>[
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return '${weekdays[local.weekday - 1]} ${local.day} ${months[local.month - 1]}';
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool _isLive(SportsAgendaEvent event) {
    final status = event.status.toLowerCase();
    if (status == 'live' || status == 'inprogress') return true;
    if (status == 'finished' || status == 'cancelled' || status == 'postponed') {
      return false;
    }
    final now = DateTime.now();
    final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
    return !now.isBefore(event.startsAt) && now.isBefore(end);
  }

  IconData _sportIcon(String sport) {
    final value = sport.toLowerCase();
    if (value.contains('fútbol') || value.contains('futbol')) return Icons.sports_soccer_rounded;
    if (value.contains('baloncesto') || value.contains('basket')) return Icons.sports_basketball_rounded;
    if (value.contains('béisbol') || value.contains('beisbol') || value.contains('baseball')) return Icons.sports_baseball_rounded;
    if (value.contains('hockey')) return Icons.sports_hockey_rounded;
    if (value.contains('voleibol') || value.contains('volleyball')) return Icons.sports_volleyball_rounded;
    if (value.contains('balonmano') || value.contains('handball')) return Icons.sports_handball_rounded;
    if (value.contains('mma')) return Icons.sports_mma_rounded;
    if (value.contains('fútbol sala') || value.contains('futsal')) return Icons.sports_soccer_rounded;
    if (value.contains('tenis')) return Icons.sports_tennis_rounded;
    if (value.contains('motor') || value.contains('f1')) return Icons.directions_car_rounded;
    if (value.contains('ciclismo')) return Icons.directions_bike_rounded;
    if (value.contains('atletismo') || value.contains('carrera')) return Icons.directions_run_rounded;
    if (value.contains('natación') || value.contains('natacion')) return Icons.pool_rounded;
    if (value.contains('boxeo') || value.contains('combate')) return Icons.sports_mma_rounded;
    if (value.contains('golf')) return Icons.sports_golf_rounded;
    if (value.contains('rugby')) return Icons.sports_rugby_rounded;
    if (value.contains('voleibol')) return Icons.sports_volleyball_rounded;
    return Icons.emoji_events_rounded;
  }

  Widget _agendaImage(
    String imageUrl, {
    double size = 48,
    required IconData fallbackIcon,
    String fallbackLabel = '',
  }) {
    final uri = Uri.tryParse(imageUrl.trim());
    final valid = uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty;

    Widget fallback() {
      final parts = fallbackLabel.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
      final label = parts.take(2).map((part) => part.substring(0, 1)).join().toUpperCase();
      if (label.isNotEmpty) {
        return Center(
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: _agendaCyan,
              fontSize: size * .29,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      }
      return Icon(fallbackIcon, color: _agendaCyan, size: size * .56);
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B203A),
        border: Border.all(color: _agendaLine, width: 1.2),
      ),
      child: ClipOval(
        child: valid
            ? Image.network(
                imageUrl,
                fit: BoxFit.contain,
                cacheWidth: (size * 2).round(),
                cacheHeight: (size * 2).round(),
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null && !wasSynchronouslyLoaded ? fallback() : child,
                errorBuilder: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }

  Widget _teamBlock(String name, String logo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _agendaImage(
          logo,
          size: 52,
          fallbackIcon: Icons.shield_rounded,
          fallbackLabel: name,
        ),
        const SizedBox(height: 7),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _participantBlock(SportsAgendaParticipant participant) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1B31),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _agendaLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _agendaImage(
            participant.imageUrl,
            size: 44,
            fallbackIcon: Icons.person_rounded,
            fallbackLabel: participant.name,
          ),
          const SizedBox(height: 6),
          Text(
            participant.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (participant.country.isNotEmpty) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              participant.country.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _agendaMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Scaffold(
      backgroundColor: _agendaBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AGENDA DEPORTIVA',
              style: TextStyle(
                color: _agendaCyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'AGENDA AUTOMÁTICA · SPORTSAPI.APP',
              style: TextStyle(
                color: _agendaMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar agenda',
            onPressed: _loading ? null : _refresh,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loading ? _agendaMuted : _agendaCyan,
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF071A39), Color(0xFF150B30)],
              ),
              border: Border(bottom: BorderSide(color: _agendaLine)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.calendar_month_rounded, color: _agendaCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loading
                        ? 'Sincronizando agenda de tus deportes favoritos…'
                        : '${events.length} eventos en la agenda',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _agendaCyan,
                    ),
                  )
                else
                  const Text(
                    'ACTUALIZACIÓN AUTOMÁTICA',
                    style: TextStyle(
                      color: _agendaGreen,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null && events.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _agendaPanel,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _agendaYellow.withAlpha(150)),
              ),
              child: Text(
                'Mostrando la última agenda guardada. SportsAPI: $_error',
                style: const TextStyle(
                  color: _agendaMuted,
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ),
          Expanded(
            child: _loading && !_hasLoaded
                ? const Center(
                    child: CircularProgressIndicator(color: _agendaCyan),
                  )
                : _error != null && events.isEmpty
                    ? _emptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'NO SE PUDO CARGAR LA AGENDA',
                        message: _error!,
                      )
                    : events.isEmpty
                        ? _emptyState(
                            icon: Icons.event_busy_rounded,
                            title: 'AÚN NO HAY EVENTOS PUBLICADOS',
                            message: 'SportsAPI mostrará aquí los partidos, carreras y competiciones de tus diez deportes favoritos cuando haya eventos programados. Actualiza para consultar el servidor.',
                          )
                        : RefreshIndicator(
                            color: _agendaCyan,
                            backgroundColor: _agendaPanel,
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                              cacheExtent: 240,
                              addAutomaticKeepAlives: false,
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final live = _isLive(event);
                                final previousDay = index > 0
                                    ? _dayLabel(events[index - 1].startsAt)
                                    : null;
                                final day = _dayLabel(event.startsAt);
                                return Column(
                                  key: ValueKey<String>(event.id),
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    if (day != previousDay)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(3, 14, 3, 8),
                                        child: Text(
                                          day,
                                          style: const TextStyle(
                                            color: _agendaCyan,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 9),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _agendaPanel,
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: live ? _agendaRed.withAlpha(190) : _agendaLine,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Row(
                                                  children: <Widget>[
                                                    Icon(
                                                      _sportIcon(event.sport),
                                                      color: _agendaCyan,
                                                      size: 15,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        event.sport.toUpperCase(),
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: _agendaMuted,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: .8,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: <Widget>[
                                                  if (event.homeScore.isNotEmpty || event.awayScore.isNotEmpty)
                                                    Text(
                                                      '${event.homeScore.isEmpty ? '-' : event.homeScore} : ${event.awayScore.isEmpty ? '-' : event.awayScore}',
                                                      style: TextStyle(
                                                        color: live ? _agendaRed : _agendaGreen,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  Text(
                                                    live ? '● EN VIVO' :
                                                      (event.statusLabel.isNotEmpty
                                                        ? event.statusLabel.toUpperCase()
                                                        : 'PROGRAMADO'),
                                                    style: TextStyle(
                                                      color: live ? _agendaRed : _agendaMuted,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'INICIO ${_timeLabel(event.startsAt)} · HORA LOCAL',
                                                    style: const TextStyle(
                                                      color: _agendaGreen,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          if (event.homeTeam.isNotEmpty &&
                                              event.awayTeam.isNotEmpty) ...<Widget>[
                                            const SizedBox(height: 7),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: <Widget>[
                                                Expanded(
                                                  child: _teamBlock(
                                                    event.homeTeam,
                                                    event.homeTeamLogo,
                                                  ),
                                                ),
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 7),
                                                  child: Text(
                                                    'VS',
                                                    style: TextStyle(
                                                      color: _agendaPink,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _teamBlock(
                                                    event.awayTeam,
                                                    event.awayTeamLogo,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else ...<Widget>[
                                            const SizedBox(height: 7),
                                            Text(
                                              event.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (event.participants.isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 9),
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: event.participants
                                                    .take(6)
                                                    .map(_participantBlock)
                                                    .toList(growable: false),
                                              ),
                                              if (event.participants.length > 6) ...<Widget>[
                                                const SizedBox(height: 5),
                                                Center(
                                                  child: Text(
                                                    '+${event.participants.length - 6} participantes',
                                                    style: const TextStyle(
                                                      color: _agendaMuted,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ] else if (event.imageUrl.isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 8),
                                              Center(
                                                child: _agendaImage(
                                                  event.imageUrl,
                                                  size: 58,
                                                  fallbackIcon: Icons.sports_rounded,
                                                ),
                                              ),
                                            ],
                                          ],
                                          if (event.competition.isNotEmpty) ...<Widget>[
                                            const SizedBox(height: 7),
                                            Text(
                                              event.competition,
                                              style: const TextStyle(
                                                color: _agendaMuted,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                          if (event.venue.isNotEmpty) ...<Widget>[
                                            const SizedBox(height: 3),
                                            Row(
                                              children: <Widget>[
                                                const Icon(Icons.location_on_outlined,
                                                    color: _agendaMuted, size: 12),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    event.venue,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: _agendaMuted,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: widget.onOpenLive,
                                              icon: const Icon(
                                                Icons.live_tv_rounded,
                                                size: 15,
                                                color: _agendaPink,
                                              ),
                                              label: const Text(
                                                'VER TRANSMISIONES',
                                                style: TextStyle(
                                                  color: _agendaPink,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _agendaPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _agendaLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: _agendaCyan, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _agendaMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ACTUALIZAR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _agendaCyan,
                      side: const BorderSide(color: _agendaCyan),
                    ),
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
