import 'dart:async';

import 'package:flutter/material.dart';

import 'automatic_live_service.dart';
import 'live_channels_screen.dart';

const Color _autoBg = Color(0xFF030814);
const Color _autoCyan = Color(0xFF00E5FF);

class AutomaticLiveScreen extends StatefulWidget {
  const AutomaticLiveScreen({
    super.key,
    required this.onOpenAgenda,
    required this.onOpenSsh101,
    required this.onOpenSsh101Encoder,
    this.isActive = true,
  });

  // Estos callbacks se conservan para no romper la navegación existente.
  final VoidCallback onOpenAgenda;
  final VoidCallback onOpenSsh101;
  final VoidCallback onOpenSsh101Encoder;
  final bool isActive;

  @override
  State<AutomaticLiveScreen> createState() => _AutomaticLiveScreenState();
}

class _AutomaticLiveScreenState extends State<AutomaticLiveScreen>
    with WidgetsBindingObserver {
  final AutomaticLiveService _service = AutomaticLiveService();
  List<ScheduledLiveEvent> _scheduled = <ScheduledLiveEvent>[];
  List<FutbolLibreEvent> _agendaEvents = <FutbolLibreEvent>[];
  Timer? _refreshTimer;
  Timer? _eventBoundaryTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) _refresh(force: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && widget.isActive) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AutomaticLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
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
    if (_refreshing || (!widget.isActive && !force)) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final settings = await AutoLiveSettings.load();
      final events = await FutbolLibreAgendaStore.load();
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
      if (result.length == 4) break;
      if (now.isBefore(item.event.startsAt) || !now.isBefore(item.removeAt)) {
        continue;
      }

      ScheduledLiveSource? selected;
      for (final candidate in item.sources) {
        if (candidate.available &&
            isDirectPlayableStream(candidate.url) &&
            !usedUrls.contains(candidate.url)) {
          selected = candidate;
          break;
        }
      }
      if (selected == null) continue;
      usedUrls.add(selected.url);

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
      final end = event.endsAt ??
          event.startsAt.add(const Duration(hours: 3));
      return now.isBefore(end);
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return upcoming
        .take(4 - activeSources.length)
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
