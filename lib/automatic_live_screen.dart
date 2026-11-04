import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'sportsapi_app_service.dart';
import 'live_channels_screen.dart';

const Color _autoBg = Color(0xFF030814);
const Color _autoCyan = Color(0xFF00E5FF);

class AutomaticLiveScreen extends StatefulWidget {
  const AutomaticLiveScreen({
    super.key,
    required this.onOpenAgenda,
    this.isActive = true,
  });

  final VoidCallback onOpenAgenda;
  final bool isActive;

  @override
  State<AutomaticLiveScreen> createState() => _AutomaticLiveScreenState();
}

class _AutomaticLiveScreenState extends State<AutomaticLiveScreen>
    with WidgetsBindingObserver {
  final AutomaticLiveService _service = AutomaticLiveService();
  List<ScheduledLiveEvent> _scheduled = <ScheduledLiveEvent>[];
  List<SportsAgendaEvent> _agendaEvents = <SportsAgendaEvent>[];
  final Map<String, DateTime> _knownEventEndTimes = <String, DateTime>{};
  Timer? _refreshTimer;
  Timer? _eventBoundaryTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // La búsqueda previa al evento continúa aunque el usuario esté en otra
    // pestaña. El tablero de vídeo sigue respetando widget.isActive.
    _refresh(force: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AutomaticLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _eventBoundaryTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      // La pestaña Live obtiene los diez deportes favoritos directamente
      // desde SportsAPI y conserva la última agenda nativa si falla la red.
      final settings = await AutoLiveSettings.load();
      List<SportsAgendaEvent> events;
      try {
        events = await SportsApiAppService().fetchFavoriteAgendaEvents();
        await SportsAgendaStore.save(events);
      } catch (_) {
        events = await SportsAgendaStore.load();
      }

      // La agenda viene de SportsAPI; diez minutos antes de cada inicio,
      // schedule() cruza las emisiones XMLTV con todas las listas M3U del usuario.
      final latest = settings.isConfigured && events.isNotEmpty
          ? await _service.schedule(
              events: events,
              now: DateTime.now(),
              settings: settings,
              forceRefresh: force,
            )
          : <ScheduledLiveEvent>[];

      if (!mounted) return;
      setState(() {
        _agendaEvents = events;
        _scheduled = latest;
      });
      _scheduleEventBoundaryRefresh();
    } catch (_) {
      // Un fallo temporal no borra las asignaciones vigentes.
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  /// Solo asigna señales a eventos que ya comenzaron y siguen en curso.
  /// Una misma URL nunca ocupa dos reproductores simultáneamente.
  List<LivePlayerSource> _playerSources() {
    final now = DateTime.now();
    final ordered = List<ScheduledLiveEvent>.of(_scheduled)
      ..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
    final usedUrls = <String>{};
    final result = <LivePlayerSource>[];

    for (final item in ordered) {
      if (result.length == 8) break;
      if (now.isBefore(item.event.startsAt) || !now.isBefore(item.removeAt)) {
        continue;
      }

      final availableCandidates = item.sources
          .where((candidate) =>
              candidate.available && isDirectPlayableStream(candidate.url))
          .toList(growable: false);
      ScheduledLiveSource? selected;
      for (final candidate in availableCandidates) {
        if (!usedUrls.contains(candidate.url)) {
          selected = candidate;
          break;
        }
      }
      if (selected == null) continue;
      final fallbackUrls = availableCandidates
          .where((candidate) =>
              candidate.url != selected!.url &&
              !usedUrls.contains(candidate.url))
          .take(3)
          .map((candidate) => candidate.url)
          .toList(growable: false);
      usedUrls.add(selected.url);
      usedUrls.addAll(fallbackUrls);

      final event = item.event;
      final teams = event.homeTeam.isNotEmpty && event.awayTeam.isNotEmpty
          ? '${event.homeTeam} vs ${event.awayTeam}'
          : event.title;
      final details = <String>[
        event.sport,
        if (event.competition.isNotEmpty) event.competition,
        teams,
        selected.channelName,
      ];

      result.add(LivePlayerSource(
        title: 'DEPORTE TOTAL 360° CANAL ${result.length + 1}',
        url: selected.url,
        subtitle: details.join(' · '),
        eventId: event.id,
        fallbackUrls: fallbackUrls,
      ));
    }
    return result;
  }

  List<LivePlayerWaitingEvent> _waitingEvents(
    List<LivePlayerSource> activeSources,
  ) {
    final now = DateTime.now();
    final activeEventIds = activeSources
        .map((source) => source.eventId)
        .whereType<String>()
        .toSet();
    final upcoming = _agendaEvents.where((event) {
      if (activeEventIds.contains(event.id)) return false;
      if (const <String>{'finished', 'cancelled', 'postponed'}
          .contains(event.status.toLowerCase())) return false;
      final end = _knownEventEndTimes[event.id] ??
          event.endsAt ??
          event.startsAt.add(const Duration(hours: 3));
      return now.isBefore(end);
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return upcoming
        .take(8 - activeSources.length)
        .map((event) {
          final teams = event.homeTeam.isNotEmpty && event.awayTeam.isNotEmpty
              ? '${event.homeTeam} vs ${event.awayTeam}'
              : event.title;
          final localStart = event.startsAt.toLocal();
          final time =
              '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
          final heading = event.competition.isNotEmpty
              ? '${event.sport} · ${event.competition}'
              : event.sport;
          final startLabel = now.isBefore(event.startsAt)
              ? 'Comienza $time'
              : 'Evento iniciado · $time';
          return LivePlayerWaitingEvent(
            heading: heading,
            match: teams,
            startLabel: startLabel,
          );
        })
        .toList(growable: false);
  }

  /// Actualiza justo al inicio o al fin del evento, además del control
  /// periódico del catálogo que continúa ejecutándose cada 45 segundos.
  void _scheduleEventBoundaryRefresh() {
    _eventBoundaryTimer?.cancel();
    final now = DateTime.now();
    final boundaries = <DateTime>[
      for (final item in _scheduled) ...<DateTime>[
        item.event.startsAt,
        item.removeAt,
      ],
    ].where((date) => date.isAfter(now)).toList()
      ..sort();

    if (boundaries.isEmpty) return;
    final delay = boundaries.first.difference(now) +
        const Duration(milliseconds: 150);
    _eventBoundaryTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleEventBoundaryRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSources = _playerSources();
    final waitingEvents = _waitingEvents(activeSources);
    return Scaffold(
      backgroundColor: _autoBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF020B19),
        title: const Text(
          'TRANSMISIONES EN VIVO',
          style: TextStyle(
            color: _autoCyan,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshing ? null : () => _refresh(force: true),
            tooltip: 'Actualizar transmisiones',
            icon: Icon(
              Icons.refresh_rounded,
              color: _refreshing ? _autoCyan.withAlpha(110) : _autoCyan,
            ),
          ),
        ],
      ),
      body: LivePlayerBoard(
        sources: activeSources,
        waitingEvents: waitingEvents,
        isActive: widget.isActive,
      ),
    );
  }
}
