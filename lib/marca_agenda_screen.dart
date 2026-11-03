import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'web_agenda_screen.dart';

const Color _agendaBg = Color(0xFF030814);
const Color _agendaPanel = Color(0xFF071326);
const Color _agendaLine = Color(0xFF123D65);
const Color _agendaCyan = Color(0xFF00E5FF);
const Color _agendaGreen = Color(0xFF39FF9C);
const Color _agendaPink = Color(0xFFFF28CF);
const Color _agendaMuted = Color(0xFFA9BDD6);
const Color _agendaRed = Color(0xFFFF3155);

typedef AgendaEventsLoader = Future<List<SportsAgendaEvent>?> Function();

/// Agenda nativa: muestra el calendario publicado por el Worker sin depender
/// de que la página de MARCA pueda renderizarse dentro de Android WebView.
class MarcaAgendaScreen extends StatefulWidget {
  const MarcaAgendaScreen({
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
  State<MarcaAgendaScreen> createState() => _MarcaAgendaScreenState();
}

class _MarcaAgendaScreenState extends State<MarcaAgendaScreen>
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
  void didUpdateWidget(covariant MarcaAgendaScreen oldWidget) {
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

    final published = await AutomaticLiveService().fetchPublishedSchedule();
    if (published != null) {
      final events = published
          .map((item) => item.event)
          .toList(growable: false);
      // Una respuesta válida vacía también limpia la caché antigua.
      await SportsAgendaStore.save(events);
      return events;
    }

    // Si el Worker aún no responde, conserva el último calendario sincronizado.
    return SportsAgendaStore.load();
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
      final visible = loaded.where((event) {
        final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
        return end.isAfter(now.subtract(const Duration(hours: 4)));
      }).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      if (!mounted) return;
      setState(() {
        _events = visible;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = 'No se pudo actualizar la agenda. Comprueba tu conexión e inténtalo de nuevo.';
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
    final now = DateTime.now();
    final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 3));
    return !now.isBefore(event.startsAt) && now.isBefore(end);
  }

  Widget _agendaImage(
    String imageUrl, {
    double size = 48,
    required IconData fallbackIcon,
  }) {
    final uri = Uri.tryParse(imageUrl.trim());
    final valid = uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty;
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
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  color: _agendaCyan,
                  size: size * .56,
                ),
              )
            : Icon(
                fallbackIcon,
                color: _agendaCyan,
                size: size * .56,
              ),
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

  Future<void> _openMarcaWeb() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WebAgendaScreen(
          pageTitle: 'PROGRAMACIÓN MARCA',
          onExit: () => Navigator.of(context).pop(),
          onOpenLive: () {
            Navigator.of(context).pop();
            widget.onOpenLive();
          },
        ),
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
              'AGENDA DE HOY',
              style: TextStyle(
                color: _agendaCyan,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'PROGRAMACIÓN DEPORTIVA · MARCA',
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
          IconButton(
            tooltip: 'Abrir programación web de MARCA',
            onPressed: _openMarcaWeb,
            icon: const Icon(Icons.open_in_browser_rounded, color: _agendaGreen),
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
                        ? 'Sincronizando programación deportiva…'
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
                            message: 'El calendario aparecerá aquí cuando el servidor sincronice la programación de MARCA. Puedes volver a intentarlo o consultar la página de origen.',
                          )
                        : RefreshIndicator(
                            color: _agendaCyan,
                            backgroundColor: _agendaPanel,
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final live = _isLive(event);
                                final previousDay = index > 0
                                    ? _dayLabel(events[index - 1].startsAt)
                                    : null;
                                final day = _dayLabel(event.startsAt);
                                return Column(
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
                                                child: Text(
                                                  event.sport.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: _agendaMuted,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: .8,
                                                  ),
                                                ),
                                              ),
                                              if (live)
                                                const Text(
                                                  '● EN VIVO',
                                                  style: TextStyle(
                                                    color: _agendaRed,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                )
                                              else
                                                Text(
                                                  _timeLabel(event.startsAt),
                                                  style: const TextStyle(
                                                    color: _agendaGreen,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
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
                                                    .map(_participantBlock)
                                                    .toList(growable: false),
                                              ),
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
                  FilledButton.icon(
                    onPressed: _openMarcaWeb,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('ABRIR MARCA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _agendaGreen,
                      foregroundColor: _agendaBg,
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
